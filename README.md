# cpputest test auto registration

Registers all test cases as separate tests in ctest system. Based on similar solutions for catch & doctest.

Usage is quite simple:
```
include(cpputest_discover)
cpputest_discover_tests(<TARGET_NAME> <OPTIONAL ARGS>)
```

list of optional args can be found within cpputest_discover.cmake
