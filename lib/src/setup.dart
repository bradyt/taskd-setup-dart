import 'dart:io';

Future<void> setup({
  required String cn,
  required String address,
  required String taskddata,
  required String pki,
  required String home,
  bool force = false,
}) async {
  var org = 'Public';
  var _user = 'First Last';

  // toc: https://taskwarrior.org/docs/taskserver/setup.html

  // 3: https://taskwarrior.org/docs/taskserver/configure.html
  await configure(
    taskddata: taskddata,
    pki: pki,
    cn: cn,
    address: address,
    force: force,
  );

  // 3: https://taskwarrior.org/docs/taskserver/control.html
  Process.runSync('taskd', ['config', 'debug.tls', '2'],
      environment: {'TASKDDATA': taskddata});

  // 4: https://taskwarrior.org/docs/taskserver/user.html
  var key = await user(
    taskddata: taskddata,
    org: org,
    user: _user,
    pki: pki,
    force: force,
  );

  // 4: https://taskwarrior.org/docs/taskserver/taskwarrior.html
  await taskwarrior(
    org: org,
    user: _user,
    key: key,
    cn: cn,
    pki: pki,
    home: home,
    force: force,
  );

  Process.runSync(
    'task',
    ['diagnostics'],
    workingDirectory: home,
    environment: {'HOME': home},
  );
  Process.runSync(
    'taskd',
    ['diagnostics'],
    environment: {'TASKDDATA': taskddata},
  );
}

Future<void> configure({
  required String taskddata,
  required String pki,
  required String cn,
  required String address,
  bool force = false,
}) async {
  // Creates $TASKDDATA/
  if (!Directory(taskddata).existsSync()) {
    Directory(taskddata).createSync(recursive: true);
  }

  // Creates $TASKDDATA/config and $TASKDDATA/orgs/
  Process.runSync('taskd', ['init'], environment: {'TASKDDATA': taskddata});

  // Modifies pki/vars
  File('$pki/vars').writeAsStringSync(
    File('$pki/vars')
        .readAsStringSync()
        .replaceAll(RegExp(r'^CN=localhost$'), 'CN=$cn'),
  );

  var pemFiles = [
    'client.cert',
    'client.key',
    'server.cert',
    'server.key',
    'server.crl',
    'ca.cert',
  ];

  // Creates pki/*.pem
  if (force == true ||
      pemFiles.any((pem) => !File('$pki/$pem.pem').existsSync())) {
    await Process.run('./generate', [], workingDirectory: pki);
  }

  for (var pem in pemFiles) {
    // Copies pki/*.pem to $TASKDDATA
    File('$pki/$pem.pem').copySync('$taskddata/$pem.pem');

    // Updates $TASKDDATA/config with $TASKDDATA/*.pem
    await Process.run('taskd', ['config', pem, '$taskddata/$pem.pem'],
        environment: {'TASKDDATA': taskddata});
  }

  // Updates $TASKDDATA/config log setting
  await Process.run('taskd', ['config', 'log', '/dev/stdout'],
      environment: {'TASKDDATA': taskddata});

  // Updates $TASKDDATA/config server setting
  await Process.run('taskd', ['config', 'server', '$address:53589'],
      environment: {'TASKDDATA': taskddata});
}

Future<String> user({
  required String taskddata,
  required String org,
  required String user,
  required String pki,
  bool force = false,
}) async {
  late String key;

  // Adds $TASKDDATA/orgs/Public/groups and $TASKDDATA/orgs/Public/users
  if (!Directory('$taskddata/orgs/$org').existsSync()) {
    await Process.run('taskd', ['add', 'org', org],
        environment: {'TASKDDATA': taskddata});
  }

  // Adds $TASKDDATA/orgs/Public/users/<uuid>/config
  (Process.runSync('taskd', ['add', 'user', org, user],
          environment: {'TASKDDATA': taskddata}).stdout as String)
      .split('\n')
      .forEach((line) {
    if (line.contains(': ')) {
      key = line.split(': ').last;
    }
  });

  if (force == true ||
      ['cert', 'key']
          .any((pem) => !File('$pki/first_last.$pem.pem').existsSync())) {
    Process.runSync('./generate.client', ['first_last'], workingDirectory: pki);
  }

  return key;
}

Future<void> taskwarrior({
  required String home,
  required String pki,
  required String org,
  required String user,
  required String key,
  required String cn,
  bool force = false,
}) async {
  var dataDir = Directory('$home/.task');
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }

  for (var pem in {
    'certificate': 'first_last.cert.pem',
    'key': 'first_last.key.pem',
    'ca': 'ca.cert.pem',
  }.entries) {
    File('$pki/${pem.value}').copySync('$home/.task/${pem.value}');

    Process.runSync(
      'task',
      [
        'rc.confirmation:no',
        'config',
        'taskd.${pem.key}',
        '--',
        '$home/.task/${pem.value}',
      ],
      workingDirectory: home,
      environment: {'HOME': home},
    );
  }

  Process.runSync(
    'task',
    [
      'rc.confirmation:no',
      'config',
      'taskd.server',
      '--',
      'localhost:53589',
    ],
    workingDirectory: home,
    environment: {'HOME': home},
  );

  Process.runSync(
    'task',
    [
      'rc.confirmation:no',
      'config',
      'taskd.credentials',
      '--',
      '$org/$user/$key',
    ],
    workingDirectory: home,
    environment: {'HOME': home},
  );

  File('$pki/vars').writeAsStringSync(
    File('$pki/vars').readAsStringSync().replaceAll('CN=$cn', 'CN=localhost'),
  );
}
