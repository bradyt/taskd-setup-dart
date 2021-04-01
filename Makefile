analyze:
	find . -name '*.dart' -o -name '*.yaml' | entr -cs 'dart analyze'

install:
	dart pub global activate --source path .
