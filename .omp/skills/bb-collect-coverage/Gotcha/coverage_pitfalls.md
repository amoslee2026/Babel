# Coverage Collection Pitfalls

## Common Issues
1. **Unreachable code**: Error-handling branches may be unreachable in normal simulation -- exclude with `// coverage off`
2. **Toggle coverage inflation**: Constant signals show 50% toggle -- exclude from toggle metrics
3. **Branch coverage gaps**: `case` default branches and ternary operators create hard-to-hit branches
4. **Functional vs code coverage**: 100% code coverage != 100% functional coverage -- always use both
5. **Cross coverage explosion**: Cross products create NxM bins -- limit to meaningful combinations
6. **Coverage across instances**: Use `option.per_instance = 1` for multi-instance modules
7. **Reset coverage**: Reset sequences may not toggle all signals -- add directed reset tests
