#ifndef STDBOOL_H
#define STDBOOL_H 1

#undef bool
#define bool _Bool

#undef true
#define true 1
#undef false
#define false 0

#undef __bool_true_false_are_defined
#define __bool_true_false_are_defined 1

#endif
