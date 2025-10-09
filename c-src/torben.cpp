#include <cstdio>
#include <cassert>
#include <array>

// from https://github.com/facebook/ThreatExchange/blob/main/pdq/cpp/hashing/torben.cpp
float torben(float m[], int n) {
  int i, less, greater, equal;
  float min, max, guess, maxltguess, mingtguess;

  min = max = m[0];
  for (i = 1; i < n; i++) {
    if (m[i] < min)
      min = m[i];
    if (m[i] > max)
      max = m[i];
  }

  while (1) {
    guess = (min + max) / 2;
    less = 0;
    greater = 0;
    equal = 0;
    maxltguess = min;
    mingtguess = max;
    for (i = 0; i < n; i++) {
      if (m[i] < guess) {
        less++;
        if (m[i] > maxltguess)
          maxltguess = m[i];
      } else if (m[i] > guess) {
        greater++;
        if (m[i] < mingtguess)
          mingtguess = m[i];
      } else {
        equal++;
      }
    }
    if (less <= (n + 1) / 2 && greater <= (n + 1) / 2)
      break;
    else if (less > greater) {
      max = maxltguess;
    } else {
      min = mingtguess;
    }
  }
  if (less >= (n + 1) / 2) {
    return maxltguess;
  } else if (less + equal >= (n + 1) / 2) {
    return guess;
  } else {
    return mingtguess;
  }
}

int main()
{
    {
        auto f = std::to_array({10.0f, 20.0f});
        printf("%f\n", torben(f.data(), f.size()));
        assert(torben(f.data(), f.size()) == 10.0);
    }

    {
        auto f = std::to_array({10.0f, 20.0f, 30.0f});
        printf("%f\n", torben(f.data(), f.size()));
        assert(torben(f.data(), f.size()) == 20.0);
    }

    {
        auto f = std::to_array({10.0f, 20.0f, 30.0f, 40.0f});
        printf("%f\n", torben(f.data(), f.size()));
        assert(torben(f.data(), f.size()) == 20.0);
    }

    {
        auto f = std::to_array({1.0f, 5.0f, 2.0f, 4.0f, 3.0f, 1.0f});
        printf("%f\n", torben(f.data(), f.size()));
        assert(torben(f.data(), f.size()) == 2.0);
    }
}
