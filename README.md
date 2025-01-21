# Learn zig calculator

## Shunting yard algorithm

<https://www.youtube.com/watch?v=ceu-7gV1wd0&t=2206s>

```
2 + 3 * 4
^ <-- It's a number:
      - Push the number to the output_stack.

output_stack: [2]
operation_stack: []
```

```
2 + 3 * 4
  ^ <-- It's an operator:
        - Loop while operation_stack is not empty.
            - Break if precedence of the last item in the
              operation_stack is smaller than current precedence.
            - Perform operation (pop two numbers from the output_stack) and
              push the value to the output_stack.
        - Push the operator to the operation_stack.

output_stack: [2]
operation_stack: [+]
```

```
2 + 3 * 4
    ^ <-- It's a number:
          - Push the number to the output_stack.

output_stack: [2, 3]
operation_stack: [+]
```

```
2 + 3 * 4
      ^ <-- It's an operator:
            - Loop while operation_stack is not empty.
                - Break if precedence of the last item in the
                  operation_stack is smaller than current precedence.
                - Perform operation (pop two numbers from the output_stack) and
                  push the value to the output_stack.
            - Push the operator to the operation_stack.

output_stack: [2, 3]
operation_stack: [+, *]
```

```
2 + 3 * 4
        ^ <-- It's a number:
              - Push the number to the output_stack.

output_stack: [2, 3, 4]
operation_stack: [+, *]
```

```
- Loop while operation_stack is not empty.
    - Perform operation(pop two numbers from the output_stack) and
      push the value to the output_stack.

output_stack: [2, 3, 4]
operation_stack: [+, *]

output_stack: [2, 12]
operation_stack: [+]

output_stack: [14]
operation_stack: []

result = 14
```
