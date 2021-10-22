
# Types in mizu

Mizu shall feature an incredibly rich typing system focused around providing 
rich and detailed specification of POD types and structures.

As well as a composition system for hybrid types called datasets.

## POD & structs

structs are considered POD in Mizu due to known compiletime sizes and 
clarity of data layout.

Integer types matching pre-defined widths
- i8, i16, i32, i64
- u8, u16, u32, u64

Floating point types of predefined widths
- f32, f64
- f32, f64

A few basic alias types
- char; alias to i8
- uchar; alias to u8
- usize; alias to system pointer size
- uptr; alias to usize

Arrays are implemented via a `Type Decorator`

# structs

structs are user POD types;

structs can just be a direct alias to another type, allowing for compile time type 
deduction.

```
struct char i8;
```

structs are fairly self explanatory, structs can be composed of POD or other structs.
```
struct Vector2 {
    x : i32;
    y : i32;
};
```

Additionally structs support internal aliasing so the above example could be rewritten as:
```
struct Vector2 i32[2] { 
    alias x Self[0];
    alias y Self[1];
};
```

## MathVector
additionally. the compiler directive @'MathVector(); being called in an alias to an 
arrayed type shall generate aliases such that;

```
struct Vector3 i32[3]{
    @'MathVector();
}
```
```
alias x Self[0];
alias y Self[1];
alias z Self[2];
```

if the struct is less than or equal to 3 elements in size and:

```
alias a Self[0];
alias b Self[1];
..
alias z Self[25];
```

#### swizzing

Swizzling can be done via the builtin @'Swizzle directive

```
@'Swizzle(a, b, {3, 2, 1, 0}); // puts 3, 2, 1, 0 in that order from a into b
```

datasets decorated with MathVector aliases will support swizzing assignments.

```
x : Vector3 = Vector3{0, 1, 2};
y : Vector3 = x.xxy; // shall assign 0, 0, 1 to y
```

This shall work even for nested structure types.


## Buffer Types

a sized vector is an array of a fixed maximum size but contains an IType sized variable that determines the size of the array size of the array.

these types are considered <BufferType> and have a few generic functions.

```
struct str256 char &[256];

x: str256 = "lmao blaze it"; // array and iterable assignment is valid
x.count(); // returns 14 elements (strings are null-terminated);
x.push("I love it"); // pushes the new iterable, but removes the null terminator before pushing if there is one
x.push_back("I love it"); // pushes "I love it" to the last element, does not overwrite the null terminator
x.clear(); // clears all elements sets count() to zero
```

## Type decorators

A feature of the language shall be whenever a type is instantiated that particular 
instantiation can have a variety of decorators added onto the type, which provide meta
information regarding how that type is organized into memory, and features which can 
be accessed.

### array_size: ``[<size of array>]`` default = 1

Any type instantiation label can be decorated with this array_size decorator.

```{code-block} rust
x: i32[4]; // instantiates an 4 i32s arrayed in memory
```

```{code-block} rust
x: i32; // instantiates an 4 i32s arrayed in memory
x'(array_size=4);
```

both of the above code is equivalent.

Instantiation directive: `array_size=<x>` 

default: 1, valid values: `inf > x >= 1`

The nth element of an array can be accessed using the`[]` operator, note that all 
types can make use of the [] operator as all types are considered to be an array of 
size = 1.

However identifiers referencing arrays of size > 1 shall result in a reference to the 
array rather referencing the exact element.

### auxillary: `#`

```{code-block}
uptime_ticks: i32#;

```
Instantiation directive: `is_meta=<true/false>`

default: 'false'

This data instantiation is considered metadata and does not contribute to packing rules,
nor does it contribute to flow optimzation. When the structure is exported, metadata is 
always appended at the end of the structure.

Use for cold non-critical path data that doesn't need to be updated much.

## Memory management decorators

These will not improve performance for you. This is a set of decorators intended to guarantee
correct memory layout behaviour, deviating from defaults with these operators may generate
a lot of bit/shift operations in the handling of the data, which will guarantee data layout
across compilers and systems,

However might not result in the most performant code.

If you're interested in describing packets, or IO standards wherein the exact
serialization/deserialization needs to be deterministic across compilers and
systems, then the `spec struct` might be more up your alley

### endian: \<no operator\>

Instantiation directive: `endian=<little/big/automatic>`

default: 'automatic'

This specifies the endianess of it's internal data types, verify against word_size in order to ensure 
you get the results you're looking for.

### packing_mode: \<no operator\>

Instantiation directive: `packing_mode=<mode>`

default: 'automatic'

valid values: 'optimized, align8, align16, align32, align64, align128, tight'

specifies how this value should be packed internally for each of it's fields.

placement directive `@` ignores packing mode.


# procs: mizu's functions.

# simple procs

procs are a relatively normal way to declare functions.

```{code-block} rust
proc get_length(x: Vector2) -> i32
{
    return sqrt(x.x * x.x + x.y * x.y);
}
```

procs can also be used to implement static methods or operators

```
struct Vector2: i32[2]
{
    @'MathVector();
    
    proc @'op_sub(self: ref Self, other: ref Vector2) -> Vector2
    {
        Vector2 {
            x: self.x - other.x,
            y: self.y - other.y,
        }
    }

    proc get_length(self: ref Self) -> i32
    {
        return sqrt(self.x * self.x + self.y * self.y);
    }
}
```

```{code-block}
x - x // calls @'op_sub

// both calls are fine for structs
x.get_length(); 
or 
Vector2.get_length(x); 
```

# Compile time polymorphism - generics

Due to mizu being classess, and all fields being clearly visible, 
procs can utilize ducktyping to deduce the code generation.

```
proc get_length_i32(x: ref <StructType>[]) -> i32
{
    sum: mut i32 = 0;
    for elem in x 
    {
        sum = sum + elem*elem;
    }
    return sum;
}
```

## Interface types
finer control over the type deduction can be assisted via "interface types"

```
interface struct VectorType : <IType>[] {
    x: <IType>;
    y: <IType>;
}

proc get_length_i32(vect: ref <VectorType>) -> i32
{
    // vect is now guaranteed to be a structure that:
    // - can be treated as an array 
    // - has a member named 'x' that is an integer type
    // - has a member named 'y' that is an integer type
    return sqrt(self.x * self.x + self.y * self.y);
}
```
Types that can be invoked for construction of interface types are: 

- IType; covers all signed integer types
- UType; covers all unsigned integer types
- UIType; covers all signed and unsigned integer types
- FType; covers all floating point types
- NumType; covers all FTypes and UITypes, all numeric types
- StructType; covers all other interface struct types.

### Interface type suffixes

The type can be suffixed with [] to denote array types.
additionally size limitation specifiers can be set in this 
suffix.

- [\>1]: this is the default, array of any size
- [\>N]: array of any size
- [N]: array of exactly X size
- [\<N]: array of at most N size
- []: same as default, array of any size

### Nested interface types

```
interface struct VectorType : <IType>[] {
    x: <IType>;
    y: <IType>;
}

interface struct QuadType: <VectorType>[4];

interface struct ModelType: <QuadType>[]
{
    name: str;
}
```

### Generic type field accesses


This below example will be perfectly inlined and you probably couldn't 
write better code by hand yourself.

```{code-block} rust
proc get_length_i32(vect: ref <UIType>[]) -> i32
{
    // This is like a C macro except it's able to deduce 
    // The individual fields

    return sqrt( 0 + @'ForEach(@'GetArrayIndexes(vect), index) {
            + vect[$index] * vect[$index]
        }
    );
}
```

For more macroed fun you can (ab)-use generics to deduce all kinds of information from the compiler

```{code-block} rust
proc reflect_and_print(the_thing: ref <StructType>) 
{
    @'ForEach(@'GetFieldNames(the_thing), field)
    {
        value: char &[32];
        if @'IsType(field, <StructType>) {
            value = @'Stringify(@'GetType(the_thing.$field));
        }
        else if @'IsType(field, <UIType>) {
            itoa(the_thing.$field, value);
        }
        else if @'IsType(field, <FType>) {
            ftoa(the_thing.$field, value);
        }
        else {
            value = "Unknown Type";
        }
            
    `   Print(
            "{}: type={} value={} field_size={} byte_offset_in_parent={}", 
            @'Stringify($field), 
            @'GetType(the_thing.$field), 
            values,
            @'GetSize(the_thing.$field),
            @'GetMemoryOffsetInParent(the_thing.$field),
        );
    }
}
```

