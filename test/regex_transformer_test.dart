import 'package:test/test.dart';
import 'package:regex_transformer/regex_transformer.dart';

void main() {
  group('RegexTransformer', () {
    test('transform', () {
      final inputs = transformTests.keys.toList();
      for (var i = 0; i < transformTests.length; i++) {
        final input = inputs[i];
        final transformers = transformTests[input]!;
        for (var j = 0; j < transformers.length; j++) {
          final output = transformers[j].transform(input);
          expect(output, equals(expectedTransformOutputs[i][j]));
        }
      }
    });

    test('transformAll', () {
      final inputs = transformAllTests.keys.toList();
      for (var i = 0; i < transformAllTests.length; i++) {
        final input = inputs[i];
        final transformers = transformAllTests[input]!;
        for (var j = 0; j < transformers.length; j++) {
          final output = transformers[j].transformAll(input);
          expect(output, equals(expectedTransformAllOutputs[i][j]));
        }
      }
    });

    group('strict', () {
      test('transform', () {
        final inputs = transformTests.keys.toList();
        var errors = 0;
        for (var i = 0; i < transformTests.length; i++) {
          final input = inputs[i];
          final transformers = transformTests[input]!;
          for (var j = 0; j < transformers.length; j++) {
            try {
              final output =
                  transformers[j].copyWith(strict: true).transform(input);
              expect(output, equals(expectedTransformOutputs[i][j]));
            } catch (e) {
              expect(e is FormatException || e is ArgumentError, equals(true));
              errors++;
            }
          }
        }
        expect(errors, equals(2));
      });

      test('transformAll', () {
        final inputs = transformAllTests.keys.toList();
        var errors = 0;
        for (var i = 0; i < transformAllTests.length; i++) {
          final input = inputs[i];
          final transformers = transformAllTests[input]!;
          for (var j = 0; j < transformers.length; j++) {
            try {
              final output =
                  transformers[j].copyWith(strict: true).transformAll(input);
              expect(output, equals(expectedTransformAllOutputs[i][j]));
            } catch (e) {
              expect(e is FormatException || e is ArgumentError, equals(true));
              errors++;
            }
          }
        }
        expect(errors, equals(1));
      });
    });
  });
}

final transformTests = <String, List<RegexTransformer>>{
  'one plus two equals fish': [
    RegexTransformer(
      regex: RegExp(r'(.*) .* (.*) .* (.*)'),
      output: r'$1 + $2 = $3',
    ),
    RegexTransformer(
      regex: RegExp(r'(?<one>.*) .* (.*) .* (?<three>.*)'),
      output: r'$one\plus$2\equals$three',
    ),
    RegexTransformer(
      regex: RegExp(r'(.*) .* (.*) .* (.*)'),
      output: r'$one + $two = $three',
    ),
    RegexTransformer(
      regex: RegExp(r'(?<one>.*) .* (?<two>.*) .* (?<three>.*)'),
      output: r'\$one + \\$two = \\\$three',
    ),
  ],
  '2 + 3 = fish': [
    RegexTransformer(
      regex: RegExp(r'(?<one>[0-9]).*(?<two>[0-9])'),
      output: r'$one + $two = $($one + $two)',
    ),
    RegexTransformer(
      regex: RegExp(r'(?<one>[0-9]).*(?<two>[0-9])'),
      output: r'$one + $two = $($three + $four)',
    ),
    RegexTransformer(
      regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
      variables: {
        'ceil': (double input) => input.ceil(),
        'combine': combine,
      },
      output: r'$1 + $2 = $(ceil(combine($3) / 100))',
    ),
    RegexTransformer(
      regex: RegExp(r'([0-9]) \+ ([0-9]) = ([a-z]*)'),
      math: true,
      output: r'$3 = $(round((sin(($2 * pi) * ($2 / $1)) +'
          r'cos(($1 * pi) * ($1 / $2))) * 10))',
    ),
  ],
};

const expectedTransformOutputs = <List<String>>[
  [
    r'one + two = fish',
    r'oneplustwoequalsfish',
    r'$one + $two = $three',
    r'$one + \two = \$three',
  ],
  [
    r'2 + 3 = 5',
    r'2 + 3 = $($three + $four)',
    r'2 + 3 = 5',
    r'fish = 5',
  ],
];

final transformAllTests = <String, List<RegexTransformer>>{
  'one plus two equals fish': [
    RegexTransformer(
      regex: RegExp(r'[a-z]+'),
      output: r'($0)',
    ),
    RegexTransformer(
      regex: RegExp(r'(fish)'),
      output: r'$fish',
    ),
    RegexTransformer(
      regex: RegExp(r'(one|two|fish)'),
      variables: {'reverse': (String input) => input.split('').reversed.join()},
      output: r'$(reverse($1))',
    ),
    RegexTransformer(
      regex: RegExp(r'(.*) .* (.*) .* (.*)'),
      variables: {
        'combine': combine,
        'last': (int input) =>
            String.fromCharCode(input.toString().codeUnits.last),
      },
      output: r'$(floor(combine($1) / 100)) + $(floor(combine($2) / 100))'
          r' = $(last(combine($3)))',
      math: true,
    ),
  ],
};

const expectedTransformAllOutputs = <List<String>>[
  [
    r'(one) (plus) (two) (equals) (fish)',
    r'one plus two equals $fish',
    r'eno plus owt equals hsif',
    r'3 + 3 = 6',
  ],
];

int combine(String input) => input.codeUnits.reduce((a, b) => a + b);
