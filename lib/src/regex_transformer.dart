import 'dart:math' as m;
import 'package:expressions/expressions.dart';
import 'package:meta/meta.dart';

/// {@template regex_transformer.RegexTransformer}
///
/// A [RegExp] paired with an output template that matches input text with
/// the [RegExp] and returns a new string based on the template with the
/// capture groups matched by the [RegExp] filled in.
///
/// {@endtemplate}
class RegexTransformer {
  /// {@macro regex_transformer.RegexTransformer}
  ///
  /// [regex] defines the [RegExp] utilized by the [transform] method. Only
  /// the first match found in the text provided to [transform] will be included
  /// in the text it outputs.
  ///
  /// Named capture groups defined within [regex] may only contain alphanumeric
  /// characters (`a-z`, `A-Z`, `0-9`) and underscores (`_`).
  ///
  /// [output] defines the template the text output by the [transform] method
  /// will follow. Capture groups matched by the [regex] may be defined within
  /// [output] by their respective names or indexes preceded by a `$`, as such
  /// if supplying a hardcoded output, it's recommended to supply [output] as
  /// a raw string (`r'...'`), otherwise every `$` will have to be escaped.
  /// __Note:__ To output a `$` without having it interpreted as an annotation
  /// defining a capture group, it must be escaped (`\$`). If included in a
  /// string that isn't raw, the `$` and the `\` preceding it must both be
  /// escaped (`\\\$`).
  ///
  /// ```dart
  /// /// This transformer defines 3 indexed capture groups and
  /// /// returns them as defined by the output template.
  /// final transformer = RegexTransformer(
  ///   regex: RegExp(r'(.*) .* (.*) .* (.*)'),
  ///   output: r'$1 + $2 = $3',
  /// );
  ///
  /// // one + two = fish
  /// print(transformer.transform('one plus two equals fish'));
  /// ```
  ///
  /// Expressions can be built within the [output] template and evaluated
  /// by the transformation methods. Expressions are defined by the `$`
  /// annotation then wrapping the expression with parentheses: `$(...)`.
  ///
  /// __Note:__ Expressions are parsed and evaluated utilizing the
  /// [expressions](https://pub.dev/packages/expressions) package.
  ///
  /// ```dart
  /// /// This transformer evaluates an expression and outputs the result.
  /// final transformer = RegexTransformer(
  ///   regex: RegExp(r'(?<one>[0-9]).*(?<two>[0-9])'),
  ///   output: r'$one + $two = $($one + $two)',
  /// );
  ///
  /// // 2 + 3 = 5
  /// print(transformer.transform('2 + 3 = fish'));
  /// ```
  ///
  /// [variables] can be provided to map variables and functions to the
  /// expression evaluator's context.
  ///
  /// ```dart
  /// /// Expressions defined in this transformer's output template can
  /// /// utilize the `ceil` and `combine` functions provided to it.
  /// final transformer = RegexTransformer(
  ///   regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
  ///   variables: {
  ///     'ceil': (double input) => input.ceil(),
  ///     'combine': (String input) => input.codeUnits.reduce((a, b) => a + b),
  ///   },
  ///   output: r'$1 + $2 = $(ceil(combine($3) / 100))',
  /// );
  ///
  /// // 2 + 3 = 5
  /// print(transformer.transform('2 + 3 = fish'));
  /// ```
  ///
  /// [math], if `true`, will map every constant and function from the
  /// [dart:math](https://api.dart.dev/dart-math/dart-math-library.html)
  /// library to the expression evaluator's context, as well as the `abs`,
  /// `ceil`, `floor`, and `round` methodds from [num], allowing them to be parsed
  /// and evaluated within any expressions included in the [output] template.
  ///
  /// ```dart
  /// /// Expressions defined in this transformer's output template can
  /// /// utilize the `dart:math` library's methods and functions, as well
  /// /// as the `abs`, `ceil`, `floor`, and `round` methods from [num].
  /// final transformer = RegexTransformer(
  ///   regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
  ///   output: r'$3 = $(round((sin(($2 * pi) * ($2 / $1)) +'
  ///       r'cos(($1 * pi) * ($1 / $2))) * 10))',
  ///   math: true,
  /// );
  ///
  /// // fish = 5
  /// print(transformer.transform('2 + 3 = fish'));
  /// ```
  ///
  /// __Note:__ If [math] is `true`, [variables] may not contain any keys
  /// equivalent to the names of any of the
  /// [dart:math](https://api.dart.dev/dart-math/dart-math-library.html)
  /// library's constants and functions.
  ///
  /// If [strict] is set to `true`, an [ArgumentError] will be thrown if any
  /// capture group annotated in the [output] template isn't matched in the text
  /// provided to the transformation methods, or a [FormatException] if an
  /// expression can't be parsed or evaluated. However, if [strict] is `false`
  /// any capture groups that aren't matched will be treated as plain text.
  /// If any unmatched capture groups are part of an expression, the expression
  /// will also be output as plain text with any of the capture groups that were
  /// matched replaced with their respective values.
  RegexTransformer({
    @required this.regex,
    @required this.output,
    this.variables,
    this.math = false,
    this.strict = false,
  })  : assert(regex != null),
        assert(output != null),
        assert(math != null),
        assert(strict != null),
        assert(
            !math ||
                variables == null ||
                variables.keys.every((expression) =>
                    !_Expression._mathExpressions.keys.contains(expression)),
            '[variables] may not contain any keys reserved by [math].'),
        _output = _OutputTemplate.from(output,
            strict: strict, variables: variables, math: math);

  /// The [RegExp] used to match any text provided to [transform].
  final RegExp regex;

  /// The template for the text output by [transform].
  final String output;

  /// The variables and functions mapped to the [Expression] evaluator's context.
  final Map<String, dynamic> variables;

  /// If `true`, will map every constant and function from the `dart:math`
  /// library to the expression evaluator's context, allowing them to be parsed
  /// and evaluated within any expressions included in the [output] template.
  final bool math;

  /// An object that parses [output] and builds text from it.
  final _OutputTemplate _output;

  /// If `true`, a [FormatException] will be thrown if any capture groups
  /// defined in [output] weren't matched in text provided to [transform] or
  /// if they weren't included in [regex]. If `false`, any unmatched capture
  /// groups will be treated as plain text.
  final bool strict;

  /// Identifies the first match of [regex] in [input] and outputs new
  /// [String] as defined by the [output] template.
  ///
  /// If [input] can't be matched by [regex], [input] will be returned
  /// unmodified.
  String transform(String input) {
    assert(input != null);

    final match = regex.firstMatch(input);

    if (match == null) {
      return input;
    }

    return _output.build(match);
  }

  /// Replaces every instance of [regex] within [input] with new text
  /// as defined by the [output] template.
  String transformAll(String input) {
    assert(input != null);

    final matches = regex.allMatches(input);
    var matchOffset = 0;

    for (var match in matches) {
      final output = _output.build(match);
      input = input.replaceRange(
          match.start - matchOffset, match.end - matchOffset, output);
      matchOffset += (match.end - match.start) - output.length;
    }

    return input;
  }

  /// Returns a copy of `this` updated with the provided values.
  RegexTransformer copyWith({
    RegExp regex,
    String output,
    Map<String, dynamic> variables,
    bool math,
    bool strict,
  }) =>
      RegexTransformer(
        regex: regex ?? this.regex,
        output: output ?? this.output,
        variables: variables ?? this.variables,
        math: math ?? this.math,
        strict: strict ?? this.strict,
      );
}

/// Parses a [RegexTransformer]'s output template and builds new text
/// based on it from a [RegExpMatch].
class _OutputTemplate {
  const _OutputTemplate(this.parts, {@required this.strict})
      : assert(parts != null),
        assert(strict != null);

  /// Splits the output template into it's respective parts:
  /// plain text, capture groups, and expressions.
  factory _OutputTemplate.from(
    String template, {
    @required Map<String, dynamic> variables,
    @required bool math,
    @required bool strict,
  }) {
    assert(template != null);
    assert(math != null);
    assert(strict != null);

    final parts = _OutputPart.parser(template,
        variables: variables, math: math, strict: strict);
    return _OutputTemplate(parts, strict: strict);
  }

  /// The parts contained within a [RegexTransformer]'s output template.
  final List<_OutputPart> parts;

  /// If `true`, the [build]er will throw an [ArgumentError] if any of
  /// the capture groups defined in the template weren't matched.
  final bool strict;

  /// Builds the output template [parts], replacing the defined
  /// capture groups with their respective [match]es, and evaluating
  /// any expressions.
  String build(RegExpMatch match) {
    assert(match != null);

    var output = '';

    // Build the output part by part.
    for (var part in parts) {
      if (part is _PlainText) {
        output += part.value;
      } else if (part is _CaptureGroup) {
        final captureGroup = match.getGroup(part.id);

        if (captureGroup == null) {
          // If the capture group wasn't matched, throw an error
          // if the transformer is [strict].
          if (strict) {
            throw ArgumentError(
                '$part was not matched within "${match.input}."');
          }

          // Otherwise, treat it as plain text.
          output += '$part';
        } else {
          // If the capture group was matched, add the
          // captured string to the output.
          output += captureGroup;
        }
      } else if (part is _Expression) {
        // Evaluate any expressions. If the transformer is [strict], an
        // [ArgumentError] will be thrown if any of the capture groups within
        // the expression weren't matched
        output += part.evaluate(match, strict: strict);
      }
    }

    return output;
  }

  @override
  String toString() => parts.join();
}

/// The base class for the parts of a [RegexTransformer]'s output template.
abstract class _OutputPart {
  const _OutputPart();

  /// Parses [input] for the different template parts contained within it:
  /// capture groups, expressions, and plain text.
  ///
  /// If [onlyCaptureGroups] is set to `true`, only the capture groups will
  /// be returned.
  static List<_OutputPart> parser(
    String input, {
    Map<String, dynamic> variables,
    bool math = false,
    bool strict = false,
    bool onlyCaptureGroups = false,
  }) {
    assert(input != null);
    assert(math != null);
    assert(strict != null);
    assert(onlyCaptureGroups != null);

    final parts = <_OutputPart>[];

    int expressionStart;
    var nestingIndex = 0;
    var sliceStart = 0;

    // Captures a slice from [sliceStart] to [sliceEnd] and
    // adds it to [parts] as plain text.
    void captureSlice(int sliceEnd) {
      if (sliceStart < sliceEnd) {
        final plainText = input.substring(sliceStart, sliceEnd);
        parts.add(_PlainText.from(plainText));
      }
    }

    for (var i = 0; i < input.length; i++) {
      // Skip the next character if an escape was found.
      if (input[i] == r'\') {
        i++;
        continue;
      }

      // If an expression is open...
      if (expressionStart != null) {
        // If an opening parentheses was found, increase the nesting index.
        if (input[i] == '(') {
          nestingIndex++;
        } else if (input[i] == ')') {
          // If a closing parentheses was found...
          if (nestingIndex > 0) {
            // Reduce the nesting index if the parentheses is nested.
            nestingIndex--;
          } else {
            // Otherwise, isolate and attempt to parse the expression.
            final expressionData = input.substring(expressionStart, i);
            final expression = _Expression.parse(expressionData,
                variables: variables, math: math);

            // Throw a [FormatException] if the transformer is [strict] and
            // the expression can't be parsed.
            if (strict && expression == null) {
              throw FormatException(
                  '$expressionData isn\'t a valid expression.');
            }

            // If the captured output group was valid, add it to [parts],
            // otherwise it will be treated as plain text.
            if (expression != null) {
              // Capture any plain text occurring before the expression.
              captureSlice(expressionStart - 2);
              // Add the expression to [parts] and set the start of
              // the next slice.
              parts.add(expression);
              sliceStart = i + 1;
            }

            expressionStart = null;
          }
        }

        continue;
      }

      // If a $ was found, check if it's an annotation.
      if (input[i] == r'$') {
        // If the $ is followed by a (, an expression was opened.
        if (!onlyCaptureGroups && input[i + 1] == '(') {
          i++;
          expressionStart = i + 1;
          continue;
        }

        // If it's not an expression, try to match a capture group annotation.
        final captureGroup = _CaptureGroup.match(input, sliceStart: i);

        // If it's not an annotation, treat it as plain text.
        if (captureGroup == null) {
          continue;
        }

        // If it is, capture any plain text occurring before
        // the capture group annotation.
        if (!onlyCaptureGroups) captureSlice(captureGroup.start);

        // Then, capture the capture group and move the iterator
        // to the start of the next slice.
        parts.add(captureGroup);
        i = captureGroup.end;
        sliceStart = i;
      }
    }

    // Add any text remaining at the end of the template as plain text.
    if (!onlyCaptureGroups) captureSlice(input.length);

    return parts;
  }
}

/// Plain text defined within a [RegexTransformer]'s output template.
class _PlainText extends _OutputPart {
  const _PlainText(this.value) : assert(value != null);

  /// Removes any escape characters (`\`) from [value], unless they themselves
  /// are escaped, and returns a [_PlainText] with the resulting value.
  factory _PlainText.from(String value) {
    assert(value != null);

    var length = value.length;
    for (var i = 0; i < length; i++) {
      if (value[i] == r'\') {
        value = value.replaceRange(i, i + 1, '');
        length--;
      }
    }

    return _PlainText(value);
  }

  /// The text to be output.
  final String value;

  @override
  String toString() => value;
}

/// A capture group defined within a [RegexTransformer]'s output template.
class _CaptureGroup extends _OutputPart {
  const _CaptureGroup(this.id, {@required this.start, @required this.end})
      : assert(id != null),
        assert(start != null),
        assert(end != null),
        assert(id is String || id is int);

  /// The name or index of the capture group this annotation refers to.
  final Object id;

  /// The index of the first character of the annotation, inclusive.
  final int start;

  /// The index of the last character of the annotation, exclusive.
  final int end;

  /// The length of the capture group annotation.
  int get length => end - start;

  /// Attempts to match a capture group annotation
  /// within [input] at [sliceStart].
  static _CaptureGroup match(String input, {@required int sliceStart}) {
    assert(input != null);
    assert(sliceStart != null);
    assert(input[sliceStart] == r'$');

    // Identify the end of the slice by finding the first invalid
    // character within [input] after [sliceStart].
    int sliceEnd;
    for (var i = sliceStart + 1; i < input.length; i++) {
      if (!RegExp(r'[a-zA-Z0-9_]').hasMatch(input[i])) {
        sliceEnd = i;
        break;
      }
    }

    sliceEnd ??= input.length;

    // If the slice is a single character, it isn't a
    // capture group annotation, return `null`.
    if (sliceEnd - sliceStart == 1) {
      return null;
    }

    // Isolate the capture group's ID.
    final groupId = input.substring(sliceStart + 1, sliceEnd);

    return _CaptureGroup(int.tryParse(groupId) ?? groupId,
        start: sliceStart, end: sliceEnd);
  }

  /// Returns a list of every capture group annotation found within [input].
  static List<_CaptureGroup> parser(String input) {
    assert(input != null);

    return _OutputPart.parser(input, onlyCaptureGroups: true)
        .cast<_CaptureGroup>();
  }

  @override
  String toString() => '\$$id';
}

/// An expression defined within a [RegexTransformer]'s output template.
class _Expression extends _OutputPart {
  const _Expression(
    this.expression, {
    @required this.captureGroups,
    @required this.variables,
    @required this.math,
    @required this.raw,
  })  : assert(expression != null),
        assert(captureGroups != null),
        assert(math != null),
        assert(raw != null);

  /// The parsed expression.
  final Expression expression;

  /// The different capture groups defined in the [expression] as variables.
  final Set<Object> captureGroups;

  /// Variables and functions to be mapped to the evaluator's context.
  final Map<String, dynamic> variables;

  /// If `true`, every constant and function from the `dart:math` library
  /// will be mapped to the evaluator's context. ([_mathExpressions])
  final bool math;

  /// The raw text the [expression] was parsed from.
  final String raw;

  /// Parses [input] as an [Expression], returns `null` if it's not
  /// a valid expression.
  static _Expression parse(
    String input, {
    @required Map<String, dynamic> variables,
    @required bool math,
  }) {
    assert(input != null);
    assert(math != null);

    // Parse the expression.
    final expression = Expression.tryParse(input);

    // If it isn't valid, return `null`.
    if (expression == null) {
      return null;
    }

    // Identify any capture groups in the expression.
    final captureGroups = Set<Object>.from(_CaptureGroup.parser(input)
        .map<Object>((captureGroup) => captureGroup.id));

    return _Expression(
      expression,
      captureGroups: captureGroups,
      variables: variables,
      math: math,
      raw: input,
    );
  }

  /// Evaluates the [expression] by providing the [match]ed [captureGroups]
  /// to the [ExpressionEvaluator] as variables.
  ///
  /// If [strict] is `true`, an [ArgumentError] will be thrown if any of
  /// the [captureGroups] weren't [match]ed. A [FormatException] will be
  /// thrown if the [expression] can't be evaluated, otherwise the expression
  /// will be treated as plain text, with the capture group annotations that
  /// were matched replaced with their respective values.
  String evaluate(RegExpMatch match, {@required bool strict}) {
    assert(match != null);
    assert(strict != null);

    // The variables and functions mapped to the evaluator.
    final context = <String, dynamic>{};

    // Add any user-provided and the `dart:math` library's
    // variables/functions to the context, if applicable.
    if (variables != null) context.addAll(variables);
    if (math) context.addAll(_mathExpressions);

    // If set the `true`, the expression can't be evaluated and
    // should be treated as plain text.
    var returnAsPlainText = false;

    // Add the matched capture groups to the context.
    for (var captureGroup in captureGroups) {
      final value = match.getGroup(captureGroup);

      // If the capture group wasn't matched, the expression
      // can't be evaluated, return it as plain text.
      if (value == null) {
        if (strict) {
          throw ArgumentError(
              '\$$captureGroup was not matched within "${match.input}"');
        } else {
          returnAsPlainText = true;
          continue;
        }
      }

      context.addAll({'\$$captureGroup': int.tryParse(value) ?? value});
    }

    // If all of the included capture groups were matched,
    // attempt to evaluate the expression.
    var evaluation;

    if (!returnAsPlainText) {
      try {
        evaluation = ExpressionEvaluator().eval(expression, context);
      } catch (_) {
        returnAsPlainText = true;
      }
    }

    // If the expression couldn't be evaluated, treat it as plain text.
    if (returnAsPlainText) {
      var plainText = raw;

      // Replace any capture group annotations that were matched
      // with their respective captured values.
      final captureGroups = _CaptureGroup.parser(raw);
      var captureOffset = 0;

      for (var captureGroup in captureGroups) {
        final groupId = '\$${captureGroup.id}';

        if (context.containsKey(groupId)) {
          final value = context[groupId].toString();

          plainText = plainText.replaceRange(captureGroup.start - captureOffset,
              captureGroup.end - captureOffset, value);

          if (value.length != captureGroup.length) {
            captureOffset += captureGroup.length - value.length;
          }
        }
      }

      // Remove any escapes from the text.
      plainText = _PlainText.from(plainText).toString();

      // If the the transformer is [strict] throw a [FormatException].
      if (strict && evaluation == null) {
        throw FormatException('"$plainText" could not be evaluated. Make sure '
            'your expression is valid and that all of the included variables '
            'and functions were provided to the transformer.');
      }

      // Otherwise return it as plain text wrapped in
      // the expression delimiters, `$(...)`.
      return '\$($plainText)';
    }

    // If the evaluation returns a double, but is a
    // valid integer, return it as an [int].
    if (evaluation is double) {
      final integer = evaluation.truncate();
      if (evaluation.remainder(integer) == 0) {
        evaluation = integer;
      }
    }

    return evaluation.toString();
  }

  /// Maps every constant and function from the `dart:math` library,
  /// as well as the `abs`, `ceil`, `floor`, and `round` methods from [num],
  /// to be evaluated as part of an [Expression].
  static final Map<String, dynamic> _mathExpressions = {
    // Constants
    'e': m.e,
    'ln2': m.ln2,
    'ln10': m.ln10,
    'log2e': m.log2e,
    'log10e': m.log10e,
    'pi': m.pi,
    'sqrt1_2': m.sqrt1_2,
    'sqrt2': m.sqrt2,
    // Functions
    'acos': m.acos,
    'asin': m.asin,
    'atan': m.atan,
    'atan2': m.atan2,
    'cos': m.cos,
    'exp': m.exp,
    'log': m.log,
    'max': m.max,
    'pow': m.pow,
    'sin': m.sin,
    'sqrt': m.sqrt,
    'tan': m.tan,
    // [num] methods
    'abs': (num input) => input.abs(),
    'round': (num input) => input.round(),
    'ceil': (num input) => input.ceil(),
    'floor': (num input) => input.floor(),
  };
}

/// Adds the [transform] and [transformAll] methods from [RegexTransformer]
/// to [String].
extension StringTransformers on String {
  /// Identifies the first match of [regex] in `this` and outputs a new
  /// string as defined by the [output] template.
  ///
  /// If the [regex] can't be matched with `this` string, the string will
  /// be output unmodified.
  String transform(
    RegExp regex,
    String output, {
    Map<String, dynamic> variables,
    bool math = false,
    bool strict = false,
  }) {
    assert(regex != null);
    assert(output != null);
    assert(math != null);
    assert(strict != null);

    final transformer = RegexTransformer(
      regex: regex,
      output: output,
      variables: variables,
      math: math,
      strict: strict,
    );

    return transformer.transform(this);
  }

  /// Returns a new string with every instance of [regex] mathced within
  /// `this` replaced with new text as defined by the [output] template.
  String transformAll(
    RegExp regex,
    String output, {
    Map<String, dynamic> variables,
    bool math = false,
    bool strict = false,
  }) {
    assert(regex != null);
    assert(output != null);
    assert(math != null);
    assert(strict != null);

    final transformer = RegexTransformer(
      regex: regex,
      output: output,
      variables: variables,
      math: math,
      strict: strict,
    );

    return transformer.transformAll(this);
  }
}

/// Adds the [transform] and [transformAll] methods from [RegexTransformer]
/// to [RegExp].
extension RegExpTransformers on RegExp {
  /// Identifies the first match of `this` in [input] and outputs a new
  /// string as defined by the [output] template.
  ///
  /// If `this` can't be matched within the [input] string, the string will
  /// be output unmodified.
  String transform(
    String input,
    String output, {
    Map<String, dynamic> variables,
    bool math = false,
    bool strict = false,
  }) {
    assert(input != null);
    assert(output != null);
    assert(math != null);
    assert(strict != null);

    final transformer = RegexTransformer(
      regex: this,
      output: output,
      variables: variables,
      math: math,
      strict: strict,
    );

    return transformer.transform(input);
  }

  /// Returns a new string with every instance of `this` matched within
  /// [input] replaced with new text as defined by the [output] template.
  String transformAll(
    String input,
    String output, {
    Map<String, dynamic> variables,
    bool math = false,
    bool strict = false,
  }) {
    assert(input != null);
    assert(output != null);
    assert(math != null);
    assert(strict != null);

    final transformer = RegexTransformer(
      regex: this,
      output: output,
      variables: variables,
      math: math,
      strict: strict,
    );

    return transformer.transformAll(input);
  }
}

extension _GetGroup on RegExpMatch {
  /// Returns the text captured by the group associated with [identifier].
  String getGroup(Object identifier) {
    assert(identifier != null);
    assert(identifier is int || identifier is String);

    return identifier is String
        ? groupNames.contains(identifier)
            ? namedGroup(identifier)
            : null
        : identifier as int <= groupCount
            ? group(identifier)
            : null;
  }
}
