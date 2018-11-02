# parser_gen
A recursive parser generator using macros in Crystal

## Usage
Parser generation is done using the `parser` macro. This macro allows you to define the grammar of your parser using a custom syntax inspired by BNF. To have your `Parser` match a string, call its `parse` method with the string you would like to match as an argument.

### Structure and Strings
The argument to `parser` must be a named tuple. The keys on the left are the names of rules, and the values on the right are grammar expressions that define them. The first rule to be matched against is always `main`. In this example, the expression for `main` is a string literal. Parsing will result in success only if the given string is `"Hello, world!"`.

```crystal
parser({
    main:   "Hello, world!"
})
```

### Regex
Regex literals can be matched as well.
```crystal
parser({
    main:   /w*/
})
```
### `>>` and `|`
To sequence multiple expressions to be matched, use the `>>` operator. The `|` operator can be used to match either its left or right hand argument.
```crystal
parser({
    main:   "Hello, " >> ("world" | "Tom") >> "!"
})
```

### `maybe` and `rep`
`maybe` allows optional matching. `rep` matches repeatedly its receiver until a match fails.
```crystal
parser({
    main:   "lol" >> ("ol").rep >> ("!").maybe
})
```
