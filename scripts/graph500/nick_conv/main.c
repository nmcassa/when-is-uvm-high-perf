#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef struct {
    int64_t u, v;
} edge_t;

int cmp_edge(const void *a, const void *b) {
    edge_t *ea = (edge_t *)a;
    edge_t *eb = (edge_t *)b;
    if (ea->u != eb->u) return (ea->u < eb->u) ? -1 : 1;
    return (ea->v < eb->v) ? -1 : (ea->v > eb->v);
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "Usage: %s input.bin output.graph num_vertices\n", argv[0]);
        return 1;
    }

    const char *infile = argv[1];
    const char *outfile = argv[2];
    int64_t n = atoll(argv[3]);

    FILE *fin = fopen(infile, "rb");
    if (!fin) { perror("fopen"); return 1; }

    fseek(fin, 0, SEEK_END);
    long filesize = ftell(fin);
    rewind(fin);

    int64_t nedge = filesize / (2 * sizeof(int64_t));
    edge_t *edges = malloc(nedge * sizeof(edge_t));

    fread(edges, sizeof(edge_t), nedge, fin);
    fclose(fin);

    printf("Read %ld edges\n", nedge);

    // normalize + remove self-loops in-place
    int64_t m = 0;
    for (int64_t i = 0; i < nedge; ++i) {
        int64_t u = edges[i].u;
        int64_t v = edges[i].v;

        if (u == v) continue;

        if (u > v) {
            int64_t tmp = u;
            u = v;
            v = tmp;
        }

        edges[m++] = (edge_t){u, v};
    }

    printf("After removing self-loops: %ld\n", m);

    // sort
    qsort(edges, m, sizeof(edge_t), cmp_edge);

    // deduplicate
    int64_t unique = 0;
    for (int64_t i = 0; i < m; ++i) {
        if (i == 0 ||
            edges[i].u != edges[i-1].u ||
            edges[i].v != edges[i-1].v) {
            edges[unique++] = edges[i];
        }
    }

    printf("After deduplication: %ld edges\n", unique);

    // degree count
    int64_t *deg = calloc(n, sizeof(int64_t));

    for (int64_t i = 0; i < unique; ++i) {
        deg[edges[i].u]++;
        deg[edges[i].v]++;
    }

    // prefix sum → CSR offsets
    int64_t *offset = malloc((n+1) * sizeof(int64_t));
    offset[0] = 0;
    for (int64_t i = 0; i < n; ++i) {
        offset[i+1] = offset[i] + deg[i];
    }

    int64_t total_adj = offset[n];
    int64_t *adj = malloc(total_adj * sizeof(int64_t));

    // reset degree for reuse
    for (int64_t i = 0; i < n; ++i) deg[i] = 0;

    // fill adjacency
    for (int64_t i = 0; i < unique; ++i) {
        int64_t u = edges[i].u;
        int64_t v = edges[i].v;

        adj[offset[u] + deg[u]++] = v;
        adj[offset[v] + deg[v]++] = u;
    }

    FILE *fout = fopen(outfile, "w");

    // Chaco header (undirected edges)
    fprintf(fout, "%ld %ld 0\n", n, unique);

    for (int64_t i = 0; i < n; ++i) {
        for (int64_t j = offset[i]; j < offset[i+1]; ++j) {
            fprintf(fout, "%ld ", adj[j] + 1);
        }
        fprintf(fout, "\n");
    }

    fclose(fout);

    printf("Done.\n");
    return 0;
}
