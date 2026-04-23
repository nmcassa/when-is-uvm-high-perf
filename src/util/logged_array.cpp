#include <fstream>
#include "logged_array.hpp"

std::ofstream logbin::out;
std::ofstream logtext::out;
std::ofstream logtext::meta;
std::ofstream logtextomp::meta;
std::ofstream* logtextomp::out = NULL;
