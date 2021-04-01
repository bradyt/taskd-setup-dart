import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';

class TaskdProcess {
  TaskdProcess(this._taskddata);

  final String _taskddata;
  late Process _process;
  final _log = Logger('TaskdProcess');

  Future<void> start() async {
    _process = await Process.start(
      'taskd',
      [
        'server',
        '--debug',
      ],
      workingDirectory: 'fixture',
      environment: {'TASKDDATA': _taskddata},
    );

    var serverReady = false;

    unawaited(_process.stdout.transform(utf8.decoder).forEach(
      (element) {
        if (element.contains('Server ready')) {
          serverReady = true;
        }
        _log.info(element);
      },
    ));

    while (serverReady == false) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> kill() async {
    _process.kill(ProcessSignal.sigkill);
  }
}
