  -W, --warn                  Show warnings
  -q, --quiet                 Do not show warnings
  --stop-on-first-error       Stop on first error
  --no-color                  Do not use color to display errors and warnings
  --log                       Generate various log files
  --log-dir                   Directory where to generate log files
  -h, -?, --help              Show Help (This screen)
  --version                   Show version and exit
  -v, --verbose               Verbose
  -I, --path                  Set include path for loaders (may be used more than once)
  --only-parse                Only proceed to parse step of loaders
  --only-metamodel            Stop after meta-model processing
  -o, --output                Output file
  --no-cc                     Do not invoke C compiler
  --make-flags                Additional options to make
  --hardening                 Generate contracts in the C code against bugs in the compiler
  --no-check-covariance       Disable type tests of covariant parameters (dangerous)
  --no-check-initialization   Disable isset tests at the end of constructors (dangerous)
  --no-check-assert           Disable the evaluation of explicit 'assert' and 'as' (dangerous)
  --no-check-autocast         Disable implicit casts on unsafe expression usage (dangerous)
  --no-check-other            Disable implicit tests: unset attribute, null receiver (dangerous)
  --separate                  Use separate compilation
  --no-inline-intern          Do not inline call to intern methods
  --inline-coloring-numbers   Inline colors and ids
  --bm-typing                 Colorize items incrementaly, used to simulate binary matrix typing
  --phmod-typing              Replace coloration by perfect hashing (with mod operator)
  --phand-typing              Replace coloration by perfect hashing (with and operator)
  --generic-resolution-tree   Use tree representation for live generic types instead of flattened representation
  --erasure                   Erase generic types
  --no-check-erasure-cast     Disable implicit casts on unsafe return with erasure-typing policy (dangerous)
