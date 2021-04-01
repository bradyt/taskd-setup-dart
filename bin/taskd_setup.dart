// ignore_for_file: avoid_print

import 'package:args/args.dart';

import 'package:taskd_setup/taskd_setup.dart';

Future<void> main(List<String> args) async {
  var parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Displays this help information.')
    ..addOption('CN', abbr: 'c', defaultsTo: 'localhost')
    ..addOption('address', abbr: 'a', defaultsTo: 'localhost')
    ..addOption('TASKDDATA', abbr: 't', defaultsTo: 'var/taskd')
    ..addOption('HOME', abbr: 'H', defaultsTo: '.')
    ..addOption('pki', abbr: 'p', defaultsTo: 'pki');

  var results = parser.parse(args);

  if (results['help']) {
    print(parser.usage);
  } else {
    print('running setup script...');

    await setup(
      cn: results['CN'],
      address: results['address'],
      taskddata: results['TASKDDATA'],
      home: results['HOME'],
      pki: results['pki'],
    );

    print('done');
  }
}
