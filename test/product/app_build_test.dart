import 'package:emotional/product/utility/validator/app_build.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppBuild build(String version, [String? number]) =>
      AppBuild.tryParse(version, number)!;

  group('AppBuild.tryParse', () {
    test('fills missing parts with zero', () {
      expect(build('1.2'), build('1.2.0'));
      expect(build('2'), build('2.0.0'));
    });

    test('rejects what is not a version', () {
      expect(AppBuild.tryParse(''), isNull);
      expect(AppBuild.tryParse('1.x.0'), isNull);
      expect(AppBuild.tryParse('1.2.3.4'), isNull);
      expect(AppBuild.tryParse('-1.0.0'), isNull);
    });

    test('compares part by part, not as one number', () {
      // The old check turned 1.0.10 into 1010 and 1.1.0 into 110.
      expect(build('1.0.10').isOlderVersionThan(build('1.1.0')), isTrue);
      expect(build('1.1.0').isOlderVersionThan(build('1.0.10')), isFalse);
      expect(build('1.1.0').isOlderVersionThan(build('1.1.0')), isFalse);
    });

    test('build numbers tell builds of one version apart', () {
      expect(build('1.1.0', '22') == build('1.1.0', '23'), isFalse);
      expect(build('1.1.0', '22').compareTo(build('1.1.0', '23')), isNegative);
      expect(
        build('1.1.0', '22').isOlderVersionThan(build('1.1.0', '99')),
        isFalse,
        reason: 'the minimum version has no build number',
      );
    });
  });

  group('decideUpdate', () {
    final running = build('1.1.0', '22');

    test('nothing to do when up to date', () {
      expect(
        decideUpdate(running: running, minimum: build('1.0.0')),
        UpdateDecision.none,
      );
      expect(
        decideUpdate(running: running, deployed: build('1.1.0', '22')),
        UpdateDecision.none,
      );
    });

    test('below the minimum: required', () {
      expect(
        decideUpdate(running: running, minimum: build('1.2.0')),
        UpdateDecision.required,
        reason: 'mobile: the store has it',
      );
      expect(
        decideUpdate(
          running: running,
          minimum: build('1.2.0'),
          deployed: build('1.2.0', '30'),
        ),
        UpdateDecision.required,
      );
    });

    test('web: no forced reload while the server lacks the minimum', () {
      expect(
        decideUpdate(
          running: running,
          minimum: build('1.2.0'),
          deployed: build('1.1.0', '22'),
        ),
        UpdateDecision.none,
      );
    });

    test('web: a new deploy is offered, not forced', () {
      expect(
        decideUpdate(running: running, deployed: build('1.1.0', '23')),
        UpdateDecision.available,
      );
      expect(
        decideUpdate(
          running: running,
          minimum: build('1.0.0'),
          deployed: build('1.1.1', '24'),
        ),
        UpdateDecision.available,
      );
    });

    test('web: a rollback is offered too', () {
      expect(
        decideUpdate(running: running, deployed: build('1.0.9', '21')),
        UpdateDecision.available,
      );
    });
  });
}
