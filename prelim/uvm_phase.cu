// ============================================================================
// uvm_phase.cu  --  Synthetic probe for the UVM "cache -> migration amplification"
//                   phase transition under oversubscription.
//
// Build (with CUPTI counters; required for A_m):
//   nvcc -O3 -std=c++14 -arch=sm_60 -DUSE_CUPTI uvm_phase.cu -o uvm_phase \
//        -I/usr/local/cuda/extras/CUPTI/include \
//        -L/usr/local/cuda/extras/CUPTI/lib64 -lcupti -Xcompiler -fopenmp
//   (P100: -arch=sm_60   A100: -arch=sm_80)
//
// Build (no CUPTI):
//   nvcc -O3 -std=c++14 -arch=sm_60 uvm_phase.cu -o uvm_phase_nocupti \
//        -Xcompiler -fopenmp
//
// NOTE: CUPTI UM counters may require NVreg_RestrictProfilingToAdminUsers=0.
//
// ---------------------------------------------------------------------------
// NORMALIZATION CONTRACT  (changed vs. earlier versions -- see `norm` column)
// ---------------------------------------------------------------------------
//   Every volume/count column is PER TIMED ITERATION.  htod, dtoh, unique,
//   faults and cold-access counts are all divided by --iters, so A_m is
//   dimensionally consistent regardless of iteration count.  Rows carry
//   norm=per_iter.  Do NOT mix these rows with output from older binaries.
//
// Metrics
// -------
//   A_m_page      = mig_bytes / unique_4KiB_bytes_touched
//   A_m_htod      = htod_bytes / unique_4KiB_bytes_touched
//   A_m_blk       = mig_bytes / (unique_2MiB_blocks * 2MiB)
//   A_m_blk_htod  = htod_bytes / (unique_2MiB_blocks * 2MiB)   <- floor is 1.0
//
//   A_m_blk_htod ~ 1  => no thrashing; every needed VABlock crossed once.
//   A_m_page >> 1 while A_m_blk_htod ~ 1  => pure GRANULARITY waste.
//   A_m_blk_htod >> 1                     => genuine capacity thrashing.
//   Reporting both is what separates "policy mispredicts" from "block too big".
//
//   cold_blks / slack_blks is the slack-law predictor: values above ~1 are
//   expected to sit above the c* boundary.
//
// Caveats
// -------
//   * --mode split: hot accesses bypass the managed buffer, so unique_* and
//     therefore all A_m variants describe the COLD stream only.
//   * --locality K reduces the unique footprint by ~K; it is a workload knob,
//     not a free speedup.
// ============================================================================

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>
#include <random>

#if defined(__linux__)
#include <unistd.h>
#endif

#ifdef USE_CUPTI
#include <cupti.h>
#endif

#define VABLOCK        (2ull << 20)   // NVIDIA UVM migration / eviction unit
#define PAGE4K         4096ull
#define PAGES_PER_BLK  (VABLOCK / PAGE4K)          // 512
#define WORDS_PER_BLK  (PAGES_PER_BLK / 32)        // 16

#define CUDA_CHECK(x) do {                                                     \
  cudaError_t e_ = (x);                                                        \
  if (e_ != cudaSuccess) {                                                     \
    fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__,              \
            cudaGetErrorString(e_));                                           \
    exit(1);                                                                   \
  }                                                                            \
} while (0)

// ---------------------------------------------------------------------------
// CUPTI unified-memory counters
// ---------------------------------------------------------------------------
struct UmCounters {
  double htod, dtoh, gpuFaultGroups, cpuFault, thrash, throttle, remoteMap;
};
static void umZero(UmCounters &c) { memset(&c, 0, sizeof(c)); }

#ifdef USE_CUPTI

static UmCounters g_um;                       // region accumulator
static uint64_t   g_t0 = ~0ULL, g_t1 = ~0ULL; // [FIX 3] region timestamp window
static int        g_dumpUm = 0, g_dumped = 0, g_dumpInWin = 0;
static int        g_dumpKind = -1;                  // [NEW] -1 = all kinds
static double     g_szHist[2][12];                  // [NEW] [0]=htod [1]=dtoh
static inline int szBucket(uint64_t v) {            // bucket i => 4KiB<<i
  int b = 0; uint64_t p = 4096;
  while (p < v && b < 11) { p <<= 1; ++b; }
  return b;
}

#define CUPTI_BUF_SIZE  (8 * 1024 * 1024)
#define CUPTI_ALIGN     4096                  // [FIX 5] page-aligned, freeable

// [FIX 5] posix_memalign so the pointer handed to free() is the one allocated.
static void CUPTIAPI bufReq(uint8_t **buffer, size_t *size, size_t *maxRec) {
  void *raw = NULL;
  if (posix_memalign(&raw, CUPTI_ALIGN, CUPTI_BUF_SIZE) != 0 || raw == NULL) {
    *buffer = NULL; *size = 0; *maxRec = 0;
    fprintf(stderr, "[warn] CUPTI buffer allocation failed\n");
    return;
  }
  *buffer = (uint8_t *)raw;
  *size   = CUPTI_BUF_SIZE;
  *maxRec = 0;
}

static void CUPTIAPI bufDone(CUcontext, uint32_t, uint8_t *buffer,
                             size_t, size_t validSize) {
  CUpti_Activity *rec = NULL;
  if (validSize > 0) {
    while (cuptiActivityGetNextRecord(buffer, validSize, &rec) == CUPTI_SUCCESS) {
      if (rec->kind != CUPTI_ACTIVITY_KIND_UNIFIED_MEMORY_COUNTER) continue;
      CUpti_ActivityUnifiedMemoryCounter2 *um =
          (CUpti_ActivityUnifiedMemoryCounter2 *)rec;

      // [NEW] compute the window verdict first so the dump can report it.
      uint64_t ts    = um->start ? um->start : (um->end ? um->end : 0);
      int      inWin = (ts >= g_t0 && ts <= g_t1);

      if (g_dumpUm && g_dumped < g_dumpUm && (!g_dumpInWin || inWin)
            && (g_dumpKind < 0 || (int) um->counterKind == g_dumpKind)) {
        fprintf(stderr,
                "[um] kind=%d value=%llu addr=0x%llx"
                "src=%u dst=%u start=%llu end=%llu inwin=%d\n",
                (int)um->counterKind,
                (unsigned long long)um->value,
                (unsigned long long)um->address,
                um->srcId, um->dstId,
                (unsigned long long)um->start,
                (unsigned long long)um->end, inWin);
        ++g_dumped;
      }
      if (!inWin) continue;

      // [FIX 3] Gate on the record's own timestamp, not a host-side flag.
      // The old g_counting flag was evaluated at flush time, so DtoH traffic
      // from the inter-iteration reset prefetch was charged to the kernel.
      ts = um->start ? um->start : (um->end ? um->end : g_t0);
      if (ts < g_t0 || ts > g_t1) continue;

      switch (um->counterKind) {
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_BYTES_TRANSFER_HTOD:
          g_um.htod += (double)um->value; 
          g_szHist[0][szBucket(um->value)] += 1.0; break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_BYTES_TRANSFER_DTOH:
          g_um.dtoh += (double)um->value; 
          g_szHist[1][szBucket(um->value)] += 1.0; break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_GPU_PAGE_FAULT:
          // UNVERIFIED: assumes value is a group count. Confirm with
          // --dump-um-in that kind=4 records carry value==1.
          g_um.gpuFaultGroups += (double)um->value; break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_CPU_PAGE_FAULT_COUNT:
          // VERIFIED by dump: one record == one fault; `value` is a constant
          // (4225016) that is NOT a count. Count records instead.
          g_um.cpuFault += 1.0; break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_THRASHING:
          g_um.thrash += 1.0;   break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_THROTTLING:
          g_um.throttle += 1.0; break;
        case CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_REMOTE_MAP:
          g_um.remoteMap += 1.0; break;
        default: break;
      }
    }
  }
  free(buffer);
}

static bool cuptiTryConfig(int nKinds,
                           CUpti_ActivityUnifiedMemoryCounterKind *kinds,
                           int devId) {
  std::vector<CUpti_ActivityUnifiedMemoryCounterConfig> cfg(nKinds);
  for (int i = 0; i < nKinds; ++i) {
    cfg[i].scope    = CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_SCOPE_PROCESS_SINGLE_DEVICE;
    cfg[i].kind     = kinds[i];
    cfg[i].deviceId = devId;
    cfg[i].enable   = 1;
  }
  return cuptiActivityConfigureUnifiedMemoryCounter(cfg.data(), nKinds)
         == CUPTI_SUCCESS;
}

static bool g_cuptiOk = false;

static void cuptiSetup(int devId) {
  CUpti_ActivityUnifiedMemoryCounterKind full[7] = {
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_BYTES_TRANSFER_HTOD,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_BYTES_TRANSFER_DTOH,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_GPU_PAGE_FAULT,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_CPU_PAGE_FAULT_COUNT,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_THRASHING,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_THROTTLING,
    CUPTI_ACTIVITY_UNIFIED_MEMORY_COUNTER_KIND_REMOTE_MAP
  };
  bool ok = cuptiTryConfig(7, full, devId);
  if (!ok) ok = cuptiTryConfig(4, full, devId);
  if (!ok) ok = cuptiTryConfig(3, full, devId);
  if (!ok) { fprintf(stderr, "[warn] CUPTI UM counters unavailable\n"); return; }
  if (cuptiActivityRegisterCallbacks(bufReq, bufDone) != CUPTI_SUCCESS) {
    fprintf(stderr, "[warn] cuptiActivityRegisterCallbacks failed\n"); return;
  }
  if (cuptiActivityEnable(CUPTI_ACTIVITY_KIND_UNIFIED_MEMORY_COUNTER)
      != CUPTI_SUCCESS) {
    fprintf(stderr, "[warn] cuptiActivityEnable failed\n"); return;
  }
  g_cuptiOk = true;
}

// [FIX 3] Drain everything produced before the region, then open the window.
static void cuptiRegionBegin() {
  if (!g_cuptiOk) return;
  g_t0 = ~0ULL; g_t1 = ~0ULL;        // reject-all while draining
  cuptiActivityFlushAll(1);
  umZero(g_um);
  memset(g_szHist, 0, sizeof(g_szHist));
  uint64_t t = 0; cuptiGetTimestamp(&t);
  g_t0 = t;
  g_t1 = ~0ULL;
}

static UmCounters cuptiRegionEnd() {
  UmCounters c; umZero(c);
  if (!g_cuptiOk) return c;
  uint64_t t = 0; cuptiGetTimestamp(&t);
  g_t1 = t;
  cuptiActivityFlushAll(1);
  c = g_um;
  g_t0 = ~0ULL;                      // closed until next region
  return c;
}
#endif // USE_CUPTI

// ---------------------------------------------------------------------------
// Device RNG + Zipf
// ---------------------------------------------------------------------------
__device__ __forceinline__ uint64_t splitmix64(uint64_t &x) {
  uint64_t z = (x += 0x9E3779B97F4A7C15ULL);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  return z ^ (z >> 31);
}
__device__ __forceinline__ double u01(uint64_t &s) {
  return (double)(splitmix64(s) >> 11) * (1.0 / 9007199254740992.0);
}

__device__ __forceinline__ uint32_t zipf_rank(double u, uint32_t n, double s) {
  if (n == 0) return 0;
  if (s <= 0.0) { uint32_t r = (uint32_t)(u * n); return r < n ? r : n - 1; }
  double N = (double)n, x;
  double oms = 1.0 - s;
  if (fabs(oms) < 1e-9) x = exp(u * log(N + 1.0));
  else x = pow((pow(N + 1.0, oms) - 1.0) * u + 1.0, 1.0 / oms);
  uint32_t r = (uint32_t)(x - 1.0);
  return r < n ? r : n - 1;
}

// [NEW] dependent FMA chain: sweeps T_compute to test whether
// T = T_compute + T_migration is additive or max().
__device__ __forceinline__ float burn(uint32_t v, uint32_t n) {
  float x = (float)(v & 0xFFFFu) + 1.0f;
  for (uint32_t f = 0; f < n; ++f) x = fmaf(x, 1.0000001f, 1.0f);
  return x;
}

// ---------------------------------------------------------------------------
// Access kernel.
//   markOnly==1 -> identical index stream, but touches only device-resident
//   bitmaps (no managed traffic), to count unique pages / blocks / cold accesses.
//
//   [FIX 7] coldSeq: partitioned sequential cold scan (LRU scan-resistance test)
//           instead of i.i.d. random cold sampling.
//   [FIX 8] locality: K consecutive accesses stay within one granule, walking
//           consecutive uint4 slots -- models real intra-page reuse.
// ---------------------------------------------------------------------------
__global__ void k_access(uint4 * __restrict__ mbuf,
                         uint4 * __restrict__ hotbuf,
                         const uint32_t * __restrict__ perm,
                         uint32_t nGran, uint32_t nHot, uint32_t hotBase,
                         double pHot, double sHot, double sCold,
                         uint32_t elemsPerGran,
                         uint64_t seed, uint32_t accPerThread,
                         uint32_t locality, int coldSeq, uint32_t flops,
                         int doWrite, int markOnly,
                         uint32_t * __restrict__ touched,
                         uint32_t * __restrict__ touchedCold,
                         unsigned long long * __restrict__ coldAccCount,
                         unsigned long long * __restrict__ sink)
{
  uint32_t tid      = blockIdx.x * blockDim.x + threadIdx.x;
  uint32_t nThreads = gridDim.x * blockDim.x;
  uint64_t st       = seed ^ (0x2545F4914F6CDD1DULL * (uint64_t)(tid + 1));
  unsigned long long acc = 0, myCold = 0;
  float fsum = 0.f;
  uint32_t nCold = nGran - nHot;

  // per-thread contiguous slice of the cold rank space (sequential mode)
  uint32_t chunk = 1, myStart = 0, cursor = 0;
  if (nCold > 0) {
    chunk = (nCold + nThreads - 1) / nThreads;
    if (chunk == 0) chunk = 1;
    myStart = (uint32_t)(((uint64_t)tid * (uint64_t)chunk) % (uint64_t)nCold);
  }

  uint32_t g = 0, offBase = 0, hotSlot = 0;
  int      isHot = 1;
  uint32_t k = locality;              // force a draw on the first access

  for (uint32_t i = 0; i < accPerThread; ++i) {
    if (k >= locality) {
      k = 0;
      double sel = u01(st);
      double ur  = u01(st);
      double uo  = u01(st);
      uint32_t rank;
      if (sel < pHot || nCold == 0) {
        hotSlot = zipf_rank(ur, nHot, sHot);
        rank    = hotBase + hotSlot; if (rank >= nGran) rank -= nGran;
        isHot   = 1;
      } else {
        uint32_t cr;
        if (coldSeq) {
          cr = (uint32_t)(((uint64_t)myStart + cursor) % (uint64_t)nCold);
          ++cursor; if (cursor >= chunk) cursor = 0;
        } else {
          cr = zipf_rank(ur, nCold, sCold);
        }
        uint64_t t = (uint64_t)hotBase + nHot + cr;
        rank       = (uint32_t)(t % nGran);
        isHot      = 0;
      }
      g       = perm[rank];
      offBase = (uint32_t)(uo * elemsPerGran);
      if (offBase >= elemsPerGran) offBase = elemsPerGran - 1;
    }

    uint32_t off = (uint32_t)(((uint64_t)offBase + k) % elemsPerGran);
    ++k;

    if (hotbuf != NULL && isHot) {              // split: hot in cudaMalloc
      size_t idx = (size_t)hotSlot * elemsPerGran + off;
      if (!markOnly) {
        uint4 v = hotbuf[idx];
        if (doWrite) { v.x += 1u; hotbuf[idx] = v; }
        if (flops) fsum += burn(v.x, flops);
        acc += v.x;
      }
      continue;
    }

    if (markOnly) {
      size_t   byteoff = ((size_t)g * elemsPerGran + off) * sizeof(uint4);
      uint64_t pg      = byteoff >> 12;
      atomicOr(&touched[pg >> 5], 1u << (pg & 31u));
      if (!isHot) {
        atomicOr(&touchedCold[pg >> 5], 1u << (pg & 31u));
        ++myCold;
      }
      continue;
    }

    size_t idx = (size_t)g * elemsPerGran + off;
    uint4 v = mbuf[idx];
    if (doWrite) { v.x += 1u; mbuf[idx] = v; }
    if (flops) fsum += burn(v.x, flops);
    acc += v.x;
  }

  if (markOnly && myCold) atomicAdd(coldAccCount, myCold);
  if (acc + (unsigned long long)fsum == 0xFFFFFFFFFFFFFFFFULL) sink[0] = acc;
}

// ---------------------------------------------------------------------------
// Host helpers
// ---------------------------------------------------------------------------
struct Args {
  double   over        = 1.5;
  double   hotFrac     = 0.25;
  double   coldRate    = 0.05;
  double   zipfCold    = 0.0;
  double   zipfHot     = 0.0;
  size_t   granule     = 4096;
  int      scattered   = 1;
  long long accesses   = 200000000LL;
  int      iters       = 3;
  int      write       = 1;
  int      resetEach   = 1;
  uint32_t locality    = 1;        // [FIX 8]
  int      coldSeq     = 0;        // [FIX 7] 0 = rand, 1 = seq
  std::string mode     = "plain";
  int      device      = 0;
  uint64_t seed        = 12345;
  int      csvHeader   = 0;
  double   capOverride = 0.0;
  int      rotate      = 0;
  int      perIter     = 0;        // [FIX 4] emit one row per iteration
  int      forceAdvise = 0;        // [FIX 9]
  int      forceMem    = 0;        // [FIX 10]
  int      dumpUm      = 0;        // [FIX 10]
  uint32_t flops       = 0;        // [NEW] fma ops per access (compute intensity)
  int      dumpUmIn    = 0;        // [NEW] restrict --dump-um to timed window
  int      dumpKind    = -1;       // [NEW] restrict --dump-um to one kind
  int      szHist      = 0;        // [NEW] print transfer-size histogram
};

static void usage() {
  printf(
  "uvm_phase [options]\n"
  "  --over F           oversubscription O = managed/capacity     (1.5)\n"
  "  --hot F            hot-set fraction h = hot/capacity         (0.25)\n"
  "  --cold F           cold access rate c                        (0.05)\n"
  "  --cold-pattern P   rand|seq  cold stream shape               (rand)\n"
  "  --zipf-cold F      Zipf s within cold set (rand only)        (0)\n"
  "  --zipf-hot F       Zipf s within hot set                     (0)\n"
  "  --locality K       K consecutive accesses per granule        (1)\n"
  "  --granule B        placement granule bytes                   (4096)\n"
  "  --contiguous       hot pages contiguous (default scattered)\n"
  "  --accesses N       total accesses per iteration              (2e8)\n"
  "  --iters N          timed iterations                          (3)\n"
  "  --read             read-only (default read-modify-write)\n"
  "  --no-reset         keep residency across iters (WARM baseline)\n"
  "  --rotate N         rotate hot window N ranks per iteration   (0)\n"
  "  --mode M           plain|preferred|accessedby|readmostly|prefetch|split\n"
  "  --cap G            override GPU capacity in GiB\n"
  "  --per-iter         emit a CSV row per iteration plus aggregate\n"
  "  --force-advise     allow advise/prefetch with millions of ranges\n"
  "  --force-mem        skip the host-RAM oversubscription guard\n"
  "  --dump-um N        dump first N raw CUPTI UM records to stderr\n"
  "  --flops K          K fma ops per access (compute intensity)   (0)\n"
  "  --dump-um-in       only dump UM records inside the timed window\n"
  "  --dump-um-kind K   only dump kind K (1=htod 2=dtoh 3=cpuflt 4=gpuflt)\n"
  "  --size-hist        print HtoD/DtoH transfer-size histogram to stderr\n"
  "  --device N   --seed N   --csv-header   --help\n");
}

static void parse(int argc, char **argv, Args &a) {
  for (int i = 1; i < argc; ++i) {
    std::string s = argv[i];
    auto nx = [&]() -> const char * { return argv[++i]; };
    if      (s == "--over")         a.over     = atof(nx());
    else if (s == "--hot")          a.hotFrac  = atof(nx());
    else if (s == "--cold")         a.coldRate = atof(nx());
    else if (s == "--zipf-cold")    a.zipfCold = atof(nx());
    else if (s == "--zipf-hot")     a.zipfHot  = atof(nx());
    else if (s == "--granule")      a.granule  = (size_t)atoll(nx());
    else if (s == "--contiguous")   a.scattered = 0;
    else if (s == "--accesses")     a.accesses = atoll(nx());
    else if (s == "--iters")        a.iters    = atoi(nx());
    else if (s == "--read")         a.write    = 0;
    else if (s == "--no-reset")     a.resetEach = 0;
    else if (s == "--rotate")       a.rotate   = atoi(nx());
    else if (s == "--mode")         a.mode     = nx();
    else if (s == "--cap")          a.capOverride = atof(nx());
    else if (s == "--device")       a.device   = atoi(nx());
    else if (s == "--seed")         a.seed     = strtoull(nx(), NULL, 10);
    else if (s == "--csv-header")   a.csvHeader = 1;
    else if (s == "--locality")     a.locality = (uint32_t)atoi(nx());
    else if (s == "--per-iter")     a.perIter  = 1;
    else if (s == "--force-advise") a.forceAdvise = 1;
    else if (s == "--force-mem")    a.forceMem = 1;
    else if (s == "--dump-um")      a.dumpUm   = atoi(nx());
    else if (s == "--flops")        a.flops    = (uint32_t)atoi(nx());
    else if (s == "--dump-um-in")   a.dumpUmIn = 1;
    else if (s == "--dump-um-kind") a.dumpKind = atoi(nx());
    else if (s == "--size-hist")    a.szHist   = 1;
    else if (s == "--cold-pattern") {
      std::string p = nx();
      if      (p == "seq")  a.coldSeq = 1;
      else if (p == "rand") a.coldSeq = 0;
      else { fprintf(stderr, "[fatal] --cold-pattern must be rand|seq\n"); exit(1); }
    }
    else { usage(); exit(s == "--help" ? 0 : 1); }
  }
  if (a.locality < 1) a.locality = 1;
  if (a.iters    < 1) a.iters    = 1;
}

static std::vector<std::pair<size_t,size_t>>
hotRanges(const std::vector<uint32_t> &perm, uint32_t nGran,
          uint32_t hotBase, uint32_t nHot, size_t granule) {
  std::vector<uint32_t> g(nHot);
  for (uint32_t i = 0; i < nHot; ++i) {
    uint32_t r = hotBase + i; if (r >= nGran) r -= nGran;
    g[i] = perm[r];
  }
  std::sort(g.begin(), g.end());
  std::vector<std::pair<size_t,size_t>> out;
  for (size_t i = 0; i < g.size(); ) {
    size_t j = i; while (j + 1 < g.size() && g[j+1] == g[j] + 1) ++j;
    out.push_back({ (size_t)g[i] * granule, (size_t)(j - i + 1) * granule });
    i = j + 1;
  }
  return out;
}

// Per-iteration measurement record. [FIX 1] everything here is ONE iteration.
struct Row {
  double ms;
  double uniqPages, uniqBlks, uniq64, coldBlks, cold64, coldAcc;
  UmCounters um;
};

int main(int argc, char **argv) {
  Args a; parse(argc, argv, a);
  CUDA_CHECK(cudaSetDevice(a.device));
  cudaDeviceProp prop; CUDA_CHECK(cudaGetDeviceProperties(&prop, a.device));

  size_t freeB = 0, totB = 0;
  CUDA_CHECK(cudaMemGetInfo(&freeB, &totB));
  size_t cap = a.capOverride > 0 ? (size_t)(a.capOverride * (1ull << 30))
                                 : (size_t)(freeB * 0.92);

  size_t granule      = a.granule;
  if (granule < sizeof(uint4) || (granule % PAGE4K) != 0) {
    fprintf(stderr, "[fatal] --granule must be a multiple of 4096\n"); return 1;
  }
  size_t elemsPerGran = granule / sizeof(uint4);
  size_t bytes = (size_t)(a.over * (double)cap);
  bytes = (bytes / granule) * granule;
  uint32_t nGran = (uint32_t)(bytes / granule);

  uint32_t nHot = (uint32_t)(((size_t)(a.hotFrac * (double)cap)) / granule);
  if (nHot < 1)     nHot = 1;
  if (nHot > nGran) nHot = nGran;

  if (a.locality > elemsPerGran) {
    fprintf(stderr, "[warn] --locality %u > elems/granule %zu; clamping\n",
            a.locality, elemsPerGran);
    a.locality = (uint32_t)elemsPerGran;
  }

  if (!prop.concurrentManagedAccess) {
    fprintf(stderr, "[fatal] device lacks concurrentManagedAccess\n");
    return 1;
  }

  // [FIX 10] Refuse to silently measure the host page cache / swap.
#if defined(__linux__)
  if (!a.forceMem) {
    long pg = sysconf(_SC_PHYS_PAGES), ps = sysconf(_SC_PAGE_SIZE);
    if (pg > 0 && ps > 0) {
      double hostB = (double)pg * (double)ps;
      if ((double)bytes > 0.70 * hostB) {
        fprintf(stderr,
                "[fatal] managed %.1f GiB exceeds 70%% of host RAM %.1f GiB; "
                "results would measure swap. Use --force-mem to override.\n",
                bytes / 1073741824.0, hostB / 1073741824.0);
        return 1;
      }
      // [NEW] slack_blks / dcold_over_slack are only meaningful when oversubscribed.
      if ((double)bytes < 0.95 * (double)freeB)
        fprintf(stderr,
                "[warn] managed %.2f GiB fits in free device memory %.2f GiB -- "
                "NOT oversubscribed; slack/c* columns are meaningless\n",
                bytes / 1073741824.0, freeB / 1073741824.0);
    }
  }
#endif

#ifdef USE_CUPTI
  g_dumpUm = a.dumpUm;
  g_dumpInWin = a.dumpUmIn;
  g_dumpKind = a.dumpKind;
  cuptiSetup(a.device);
#else
  if (a.dumpUm) fprintf(stderr, "[warn] --dump-um requires -DUSE_CUPTI\n");
#endif

  // ---- allocations -------------------------------------------------------
  uint4 *mbuf = NULL;
  CUDA_CHECK(cudaMallocManaged(&mbuf, bytes));

  std::vector<uint32_t> hperm(nGran);
  for (uint32_t i = 0; i < nGran; ++i) hperm[i] = i;
  if (a.scattered) {
    std::mt19937_64 rng(a.seed ^ 0xABCDEF);
    std::shuffle(hperm.begin(), hperm.end(), rng);
  }
  uint32_t *dperm = NULL;
  CUDA_CHECK(cudaMalloc(&dperm, (size_t)nGran * sizeof(uint32_t)));
  CUDA_CHECK(cudaMemcpy(dperm, hperm.data(), (size_t)nGran * sizeof(uint32_t),
                        cudaMemcpyHostToDevice));

  size_t nPages4K = bytes >> 12;
  size_t bmWords  = (nPages4K + 31) / 32;
  size_t nBlkTot  = (nPages4K + PAGES_PER_BLK - 1) / PAGES_PER_BLK;

  uint32_t *dTouched = NULL, *dTouchedCold = NULL;
  CUDA_CHECK(cudaMalloc(&dTouched,     bmWords * sizeof(uint32_t)));
  CUDA_CHECK(cudaMalloc(&dTouchedCold, bmWords * sizeof(uint32_t)));
  unsigned long long *dColdAcc = NULL, *dSink = NULL;
  CUDA_CHECK(cudaMalloc(&dColdAcc, sizeof(unsigned long long)));
  CUDA_CHECK(cudaMalloc(&dSink,    sizeof(unsigned long long)));
  CUDA_CHECK(cudaMemset(dSink, 0, sizeof(unsigned long long)));

  uint4 *hotbuf = NULL;
  if (a.mode == "split") {
    size_t hb = (size_t)nHot * granule;
    if (hb > freeB * 0.85) {
      fprintf(stderr, "[fatal] split mode: hot set %.2f GiB exceeds device\n",
              hb / 1073741824.0);
      return 1;
    }
    CUDA_CHECK(cudaMalloc(&hotbuf, hb));
    CUDA_CHECK(cudaMemset(hotbuf, 1, hb));
    fprintf(stderr, "[warn] split mode: unique_*/A_m_* describe the COLD "
                    "stream only (hot accesses bypass managed memory)\n");
  }

  // ---- populate managed pages on the host --------------------------------
  {
    char *p = (char *)mbuf;
#ifdef _OPENMP
#pragma omp parallel for schedule(static)
#endif
    for (long long g = 0; g < (long long)nGran; ++g)
      *(volatile uint32_t *)(p + (size_t)g * granule) = (uint32_t)g;
  }
  CUDA_CHECK(cudaMemPrefetchAsync(mbuf, bytes, cudaCpuDeviceId));
  CUDA_CHECK(cudaDeviceSynchronize());

  // ---- placement hints ---------------------------------------------------
  // [FIX 9] guard against multi-million cudaMemAdvise calls on scattered sets.
  const size_t kMaxRanges = 262144;
  auto applyHints = [&](uint32_t hotBase) {
    if (a.mode == "plain" || a.mode == "split") return;
    auto rs = hotRanges(hperm, nGran, hotBase, nHot, granule);
    if (rs.size() > kMaxRanges && !a.forceAdvise) {
      fprintf(stderr,
              "[fatal] mode '%s' would issue %zu range calls (scattered "
              "layout). Use --contiguous, or --force-advise to proceed.\n",
              a.mode.c_str(), rs.size());
      exit(1);
    }
    char *base = (char *)mbuf;
    for (auto &r : rs) {
      if (a.mode == "preferred")
        CUDA_CHECK(cudaMemAdvise(base + r.first, r.second,
                                 cudaMemAdviseSetPreferredLocation, a.device));
      else if (a.mode == "accessedby")
        CUDA_CHECK(cudaMemAdvise(base + r.first, r.second,
                                 cudaMemAdviseSetAccessedBy, a.device));
      else if (a.mode == "readmostly")
        CUDA_CHECK(cudaMemAdvise(base + r.first, r.second,
                                 cudaMemAdviseSetReadMostly, a.device));
      else if (a.mode == "prefetch")
        CUDA_CHECK(cudaMemPrefetchAsync(base + r.first, r.second, a.device));
    }
    CUDA_CHECK(cudaDeviceSynchronize());
  };
  auto clearHints = [&](uint32_t hotBase) {
    if (a.mode == "plain" || a.mode == "split" || a.mode == "prefetch") return;
    auto rs = hotRanges(hperm, nGran, hotBase, nHot, granule);
    char *base = (char *)mbuf;
    for (auto &r : rs) {
      if (a.mode == "preferred")
        cudaMemAdvise(base + r.first, r.second,
                      cudaMemAdviseUnsetPreferredLocation, a.device);
      else if (a.mode == "accessedby")
        cudaMemAdvise(base + r.first, r.second,
                      cudaMemAdviseUnsetAccessedBy, a.device);
      else if (a.mode == "readmostly")
        cudaMemAdvise(base + r.first, r.second,
                      cudaMemAdviseUnsetReadMostly, a.device);
    }
    CUDA_CHECK(cudaDeviceSynchronize());
  };

  // ---- launch geometry ---------------------------------------------------
  int threads = 256, blocks = 4096;
  uint32_t nThreads = (uint32_t)threads * blocks;
  uint32_t accPerThread =
      (uint32_t)std::max(1LL, a.accesses / (long long)nThreads);
  if (accPerThread < 8)
    fprintf(stderr, "[warn] accPerThread=%u -- no temporal reuse; "
                    "use --accesses >= %lld\n", accPerThread,
                    8LL * nThreads);
  long long realAccesses = (long long)accPerThread * nThreads;
  double pHot = 1.0 - a.coldRate;

  // ---- iterate -----------------------------------------------------------
  std::vector<Row> rows(a.iters);
  cudaEvent_t ev0, ev1;
  CUDA_CHECK(cudaEventCreate(&ev0));
  CUDA_CHECK(cudaEventCreate(&ev1));
  std::vector<uint32_t> hbm(bmWords), hbmC(bmWords);

  for (int it = 0; it < a.iters; ++it) {
    uint32_t hotBase = (uint32_t)(((long long)a.rotate * it) % (long long)nGran);
    Row &row = rows[it];
    umZero(row.um);

    // (1) mark-only pass: identical index stream, device memory only.
    CUDA_CHECK(cudaMemset(dTouched,     0, bmWords * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemset(dTouchedCold, 0, bmWords * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemset(dColdAcc,     0, sizeof(unsigned long long)));
    k_access<<<blocks, threads>>>(mbuf, hotbuf, dperm, nGran, nHot, hotBase,
                                  pHot, a.zipfHot, a.zipfCold,
                                  (uint32_t)elemsPerGran,
                                  a.seed + 0x1000 * it, accPerThread,
                                  a.locality, a.coldSeq, a.flops,
                                  a.write, /*markOnly=*/1,
                                  dTouched, dTouchedCold, dColdAcc, dSink);
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(hbm.data(),  dTouched,     bmWords * sizeof(uint32_t),
                          cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(hbmC.data(), dTouchedCold, bmWords * sizeof(uint32_t),
                          cudaMemcpyDeviceToHost));
    unsigned long long hColdAcc = 0;
    CUDA_CHECK(cudaMemcpy(&hColdAcc, dColdAcc, sizeof(hColdAcc),
                          cudaMemcpyDeviceToHost));

    uint64_t uniq = 0, uniqBlk = 0, coldBlk = 0, uniq64 = 0, cold64 = 0;
    for (size_t b = 0; b < nBlkTot; ++b) {
      uint32_t any = 0, anyC = 0;
      size_t w0 = b * WORDS_PER_BLK;
      size_t w1 = std::min(bmWords, w0 + (size_t)WORDS_PER_BLK);
      for (size_t w = w0; w < w1; ++w) {
        uint32_t x = hbm[w], xc = hbmC[w];
        any  |= x;  anyC |= xc;
        uniq += (uint64_t)__builtin_popcount(x);
        if (x  & 0x0000FFFFu) ++uniq64;      // [NEW] 64 KiB granule
        if (x  & 0xFFFF0000u) ++uniq64;
        if (xc & 0x0000FFFFu) ++cold64;
        if (xc & 0xFFFF0000u) ++cold64;
      }
      if (any)  ++uniqBlk;
      if (anyC) ++coldBlk;
    }
    row.uniq64 = (double)uniq64;
    row.cold64 = (double)cold64;
    row.uniqPages = (double)uniq;
    row.uniqBlks  = (double)uniqBlk;
    row.coldBlks  = (double)coldBlk;
    row.coldAcc   = (double)hColdAcc;

    // (2) residency reset (excluded from both the clock and the counters).
    if (a.resetEach) {
      CUDA_CHECK(cudaMemPrefetchAsync(mbuf, bytes, cudaCpuDeviceId));
      CUDA_CHECK(cudaDeviceSynchronize());
    }
    applyHints(hotBase);

    // (3) timed pass. [FIX 3] counter window == timing window.
#ifdef USE_CUPTI
    cuptiRegionBegin();
#endif
    CUDA_CHECK(cudaEventRecord(ev0));
    k_access<<<blocks, threads>>>(mbuf, hotbuf, dperm, nGran, nHot, hotBase,
                                  pHot, a.zipfHot, a.zipfCold,
                                  (uint32_t)elemsPerGran,
                                  a.seed + 0x1000 * it, accPerThread,
                                  a.locality, a.coldSeq, a.flops,
                                  a.write, /*markOnly=*/0,
                                  dTouched, dTouchedCold, dColdAcc, dSink);
    CUDA_CHECK(cudaEventRecord(ev1));
    CUDA_CHECK(cudaEventSynchronize(ev1));
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaGetLastError());
#ifdef USE_CUPTI
    row.um = cuptiRegionEnd();
#endif
    float ms = 0.f; CUDA_CHECK(cudaEventElapsedTime(&ms, ev0, ev1));
    row.ms = (double)ms;
    clearHints(hotBase);
  }

  // ---- aggregate ---------------------------------------------------------
    double totalMs = 0.0;
  for (int i = 0; i < a.iters; ++i) totalMs += rows[i].ms;

  // [NEW] Under --no-reset, iteration 0 is a cold fill; averaging it with warm
  // iterations produced the bogus A_m_blk_htod=0.25 row. Warm-only mean.
  int aggFrom = (!a.resetEach && a.iters > 1) ? 1 : 0;
  int aggN    = a.iters - aggFrom;
  int aggTag  = aggFrom ? -2 : -1;          // -2 = warm-only mean

  Row agg; memset(&agg, 0, sizeof(agg)); umZero(agg.um);
  for (int i = aggFrom; i < a.iters; ++i) {
    agg.ms         += rows[i].ms;
    agg.uniqPages  += rows[i].uniqPages;
    agg.uniqBlks   += rows[i].uniqBlks;
    agg.uniq64     += rows[i].uniq64;
    agg.cold64     += rows[i].cold64;
    agg.coldBlks   += rows[i].coldBlks;
    agg.coldAcc    += rows[i].coldAcc;
    agg.um.htod           += rows[i].um.htod;
    agg.um.dtoh           += rows[i].um.dtoh;
    agg.um.gpuFaultGroups += rows[i].um.gpuFaultGroups;
    agg.um.cpuFault       += rows[i].um.cpuFault;
    agg.um.thrash         += rows[i].um.thrash;
    agg.um.throttle       += rows[i].um.throttle;
    agg.um.remoteMap      += rows[i].um.remoteMap;
  }
  double inv = 1.0 / (double)aggN;
  agg.ms *= inv; agg.uniqPages *= inv; agg.uniqBlks *= inv;
  agg.uniq64 *= inv; agg.cold64 *= inv;
  agg.coldBlks *= inv; agg.coldAcc *= inv;
  agg.um.htod *= inv; agg.um.dtoh *= inv; agg.um.gpuFaultGroups *= inv;
  agg.um.cpuFault *= inv; agg.um.thrash *= inv; agg.um.throttle *= inv;
  agg.um.remoteMap *= inv;
    
  // [FIX 4] warm = mean of iterations after the first (meaningful with --no-reset)
  double timeLastS = rows[a.iters - 1].ms / 1000.0;
  double timeWarmS = timeLastS;
  if (a.iters > 1) {
    double w = 0; for (int i = 1; i < a.iters; ++i) w += rows[i].ms;
    timeWarmS = w / (double)(a.iters - 1) / 1000.0;
  }

  double slackBytes = (double)cap - (double)nHot * (double)granule;
  if (slackBytes < 0) slackBytes = 0;
  double slackBlks  = slackBytes / (double)VABLOCK;

  // ---- emit --------------------------------------------------------------
  if (a.csvHeader)
    printf("gpu,mode,O,h,c,cold_pattern,locality,zipf_cold,zipf_hot,"
           "granule,layout,rw,reset,rotate,"
           "managed_GiB,cap_GiB,hot_GiB,nGran,nHot,slack_blks,"
           "iters,iter,accesses,accPerThread,"
           "time_total_s,time_s,time_last_s,time_warm_s,"
           "Maccess_per_s,useful_GBs,"
           "unique_GiB,unique_64k_GiB,unique_blk_GiB,cold_acc,cold_blks,cold_blk_GiB,"
           "dcold_over_slack,"
           "htod_GiB,dtoh_GiB,mig_GiB,"
           "A_m_page,A_m_htod,A_m_64k,A_m_64k_htod,A_m_blk,A_m_blk_htod,"
           "gpu_fault_groups,cpu_faults,thrash_evt,throttle_evt,remote_map,"
           "norm\n");

  auto emit = [&](int iterIdx, const Row &r) {
    double secs        = r.ms / 1000.0;
    double uniqueBytes = r.uniqPages * (double)PAGE4K;
    double uniqBlkB    = r.uniqBlks  * (double)VABLOCK;
    double coldBlkB    = r.coldBlks  * (double)VABLOCK;
    double usefulBytes = (double)realAccesses * sizeof(uint4);
    double achievedGBs = secs > 0 ? usefulBytes / secs / 1e9 : 0.0;
    double accPerSec   = secs > 0 ? (double)realAccesses / secs : 0.0;
    double dOverS      = slackBlks > 0 ? r.coldBlks / slackBlks : -1.0;
    double uniq64B = r.uniq64 * 65536.0;

    printf("%s,%s,%.3f,%.4f,%.5f,%s,%u,%.2f,%.2f,"
           "%zu,%s,%s,%s,%d,"
           "%.2f,%.2f,%.3f,%u,%u,%.0f,"
           "%d,%d,%lld,%u,"
           "%.4f,%.4f,%.4f,%.4f,"
           "%.2f,%.2f,"
           "%.4f,%.4f,%.4f,%.0f,%.0f,%.4f,"
           "%.4f,",
           prop.name, a.mode.c_str(), a.over, a.hotFrac, a.coldRate,
           a.coldSeq ? "seq" : "rand", a.locality, a.zipfCold, a.zipfHot,
           granule, a.scattered ? "scattered" : "contiguous",
           a.write ? "rmw" : "ro", a.resetEach ? "reset" : "warm", a.rotate,
           bytes / 1073741824.0, cap / 1073741824.0,
           (double)nHot * granule / 1073741824.0,
           nGran, nHot, slackBlks,
           a.iters, iterIdx, realAccesses, accPerThread,
           totalMs / 1000.0, secs, timeLastS, timeWarmS,
           accPerSec / 1e6, achievedGBs,
           uniqueBytes / 1073741824.0, uniqBlkB / 1073741824.0,
           uniqBlkB / 1073741824.0,
           r.coldAcc, r.coldBlks, coldBlkB / 1073741824.0,
           dOverS);

#ifdef USE_CUPTI
    if (g_cuptiOk) {
      double mig = r.um.htod + r.um.dtoh;
      char b1[24], b2[24], b3[24], b4[24], b5[24], b6[24];
      auto f = [](char *b, double num, double den, bool ok) -> char * {
        if (ok && den > 0) snprintf(b, sizeof(b), "%.4f", num / den);
        else               snprintf(b, sizeof(b), "NA");
        return b;
      };
      printf("%.4f,%.4f,%.4f,%s,%s,%s,%s,%s,%s,%.1f,%.1f,%.1f,%.1f,%.1f,per_iter\n",
             r.um.htod / 1073741824.0, r.um.dtoh / 1073741824.0,
             mig / 1073741824.0,
             f(b1, mig,       uniqueBytes, mig       > 0),
             f(b2, r.um.htod, uniqueBytes, r.um.htod > 0),
             f(b5, mig,       uniq64B,     mig       > 0),
             f(b6, r.um.htod, uniq64B,     r.um.htod > 0),
             f(b3, mig,       uniqBlkB,    mig       > 0),
             f(b4, r.um.htod, uniqBlkB,    r.um.htod > 0),
             r.um.gpuFaultGroups, r.um.cpuFault,
             r.um.thrash, r.um.throttle, r.um.remoteMap);
    } else {
        printf("NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,per_iter\n");
    }      
#else
      printf("NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,per_iter\n");
#endif
  };

#ifdef USE_CUPTI
  if (a.szHist && g_cuptiOk) {
    const char *dir[2] = { "htod", "dtoh" };
    for (int d = 0; d < 2; ++d)
      for (int i = 0; i < 12; ++i)
        if (g_szHist[d][i] > 0)
          fprintf(stderr, "[hist] %s %7zu B  %.0f\n",
                  dir[d], (size_t)4096 << i, g_szHist[d][i]);
  }
#endif

  if (a.perIter) for (int i = 0; i < a.iters; ++i) emit(i, rows[i]);
  emit(aggTag, agg);   // iter=-1 : mean over iterations

  cudaFree(mbuf); cudaFree(dperm); cudaFree(dTouched); cudaFree(dTouchedCold);
  cudaFree(dColdAcc); cudaFree(dSink);
  if (hotbuf) cudaFree(hotbuf);
  return 0;
}
