# regex_transformer

Transforms text by taking capture groups matched by a [RegExp] and outputting
them as plain text and/or evaluating them as expressions, as defined by an
output template.

# Usage

```dart
import 'package:regex_transformer/regex_transformer.dart';
```

[RegexTransformer] has two methods: `transform` and `transformAll`.

`transform` matches the [RegExp] with the first match found in the input text
and returns the output template with the matched capture groups.

`transformAll` takes every [RegExp] match found in the input text and replaces
each match with that match's parsed output.

## Capture Groups

A [RegExp]'s capture groups can be output by annotating them in the output
template with a `$` followed by the name or index of the capture group.

__Note:__ Because the `$` character used to inject variables into strings in
dart, output templates should be provided as a raw string (`r'...'`), otherwise
every `$` annotation will have to be escaped (`\$`).

### Indexed capture groups

```dart
/// This transformer defines 3 indexed capture groups and
/// returns them as defined by the output template.
final transformer = RegexTransformer(
  regex: RegExp(r'(.*) .* (.*) .* (.*)'),
  output: r'$1 + $2 = $3',
);

// one + two = fish
print(transformer.transform('one plus two equals fish'));
```

__Note:__ `$0` can be used to output the entire match.

```dart
/// This transformer wraps the entire match in parentheses.
final transformer = RegexTransformer(
  regex: RegExp(r'[a-z]+'),
  output: r'($0)',
);

// (one) (plus) (two) (equals) (fish)
print(transformer.transformAll('one plus two equals fish'));
```

### Named capture groups

```dart
/// This transformer defines 3 indexed capture groups and
/// returns them as defined by the output template.
final transformer = RegexTransformer(
  regex: RegExp(r'(?<one>.*) .* (?<two>.*) .* (?<three>.*)'),
  output: r'$one + $two = $three',
);

// one + two = fish
print(transformer.transform('one plus two equals fish'));
```

__Note:__ Named capture groups are also assigned an index, so keep in mind if
using a combination of named and indexed capture group annotations that the
indexed annotations must factor the named capture groups into the count.

### Escapes

A backslash (`\`) can be used to escape a `$` character to have it output
as plain text, rather than to annotate a capture group, and can also be used
to break a capture group's ID, allowing it to be output next to other
alphanumeric characters without a space or other character.

__Note:__ Backslashes will have to be escaped with another backslash (`\\`) to
have one output anywhere in your output template as plain text, regardless of
whether it's being used as an escape or not.

```dart
/// This transformer utilizes escapes to break the capture groups' IDs, so
/// they can be output directly next to other alphanumeric characters.
final transformer = RegexTransformer(
  regex: RegExp(r'(?<one>.*) .* (?<two>.*) .* (?<three>.*)'),
  output: r'$one\plus$two\equals\$three',
);

// oneplustwoequals$three
print(transformer.transform('one plus two equals fish'));
```

## Expressions

Expressions can be defined in output templates and evaluated by the
transformation methods, and can handle most standard operations.

Like capture groups, expression are annotated with a `$`, but are wrapped
with parentheses: `$(...)`.

__Note:__ Expressions are parsed and evaluated utilizing the
[expressions](https://pub.dev/packages/expressions) package.

```dart
/// This transformer evaluates an expression and outputs the result.
final transformer = RegexTransformer(
  regex: RegExp(r'(?<one>[0-9]).*(?<two>[0-9])'),
  output: r'$one + $two = $($one + $two)',
);

// 2 + 3 = 5
print(transformer.transform('2 + 3 = fish'));
```

### Variables & Functions

Variables and functions can be provided to the expression evaluator's context
to parse and evaluate them as part of the expression.

```dart
/// Expressions defined in this transformer's output template can
/// utilize the `ceil` and `combine` functions provided to it.
final transformer = RegexTransformer(
  regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
  variables: {
    'ceil': (double input) => input.ceil(),
    'combine': (String input) => input.codeUnits.reduce((a, b) => a + b),
    'oneHundred': 100,
  },
  output: r'$1 + $2 = $(ceil(combine($3) / oneHundred))',
);

// 2 + 3 = 5
print(transformer.transform('2 + 3 = fish'));
```

```dart
/// This transformer reverses the matched word.
final transformer = RegexTransformer(
  regex: RegExp(r'[a-z]+'),
  variables: {'reverse': (String input) => input.split('').reversed.join()},
  output: r'$(reverse($0))',
);

/// eno + owt = hsif
print(transformer.transformAll('one + two = fish'));
```

### Math

By setting [RegexTransformer]'s `math` parameter to `true`, every constant
and function in the [dart:math](https://api.dart.dev/dart-math/dart-math-library.html)
library, as well as [num]'s `abs`, `round`, `ceil`, and `floor` methods will
be provided to the expression evaluator's context and can be utilized within
expressions.

```dart
/// Expressions defined in this transformer's output template can
/// evaluate the `dart:math` library's constants and functions.
final transformer = RegexTransformer(
  regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
  output: r'$3 = $(round((sin(($2 * pi) * ($2 / $1)) +'
      r'cos(($1 * pi) * ($1 / $2))) * 10))',
  math: true,
);

// fish = 5
print(transformer.transform('2 + 3 = fish'));
```

# Strict Transformers

Setting [RegexTransformer]'s `strict` parameter to `true` will result in
exceptions being thrown should there be any errors while parsing the output
template or the input text.

If any capture groups annotated in the output template aren't matched in
the text input into the transformation methods an [ArgumentError] will be
thrown, while a [FormatException] will be thrown if an expression can't
be parsed or evaluated.

```dart
/// Any text transformed by this transformer will throw an [ArgumentError] as
/// the [RegExp]'s capture groups aren't named, but the output template calls
/// for named capture groups.
final transformer = RegexTransformer(
  regex: RegExp(r'(.*) .* (.*) .* (.*)'),
  output: r'$one + $two = $three',
  strict: true,
);
```

# Extension Methods

This package also extends [String] and [RegExp] with [RegexTransformer]'s
`transform` and `transformAll` methods.

__Note:__ These methods are intended to be used for one-off transformations.
If transforming multiple inputs with the same [RegExp] and output template, it's
computationally more efficient to create a [RegexTransformer], as these methods
parse the output template every time they're called, while a [RegexTransformer]
will only parse the output template once upon initialization.

## String

```dart
final myString = 'one plus two equals fish';

// one + two = fish
print(myString.transform(RegExp(r'(.*) .* (.*) .* (.*)'), r'$1 + $2 = $3'));

// (one) (plus) (two) (equals) (fish)
print(myString.transformAll(RegExp(r'[a-z]+'), r'($0)'));
```

## RegExp

```dart
final myRegex = RegExp(r'(.*) .* (.*) .* (.*)');

// one + two = fish
print(myRegex.transform('one plus two equals fish', r'$1 + $2 = $3'));
```

```dart
final myRegex = RegExp(r'[a-z]+');

// (one) (plus) (two) (equals) (fish)
print(myRegex.transformAll('one plus two equals fish', r'($0)'));
```
