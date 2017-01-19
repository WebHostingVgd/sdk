// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.loader;

import 'dart:async' show
    Future;

import 'dart:collection' show
    Queue;

import 'ast_kind.dart' show
    AstKind;

import 'builder/builder.dart' show
    LibraryBuilder;

import 'errors.dart' show
    InputError,
    firstSourceUri;

import 'target_implementation.dart' show
    TargetImplementation;

import 'ticker.dart' show
    Ticker;

abstract class Loader<L> {
  final Map<Uri, LibraryBuilder> builders = <Uri, LibraryBuilder>{};

  final Queue<LibraryBuilder> unparsedLibraries = new Queue<LibraryBuilder>();

  final List<L> libraries = <L>[];

  final TargetImplementation target;

  LibraryBuilder coreLibrary;

  LibraryBuilder first;

  int byteCount = 0;

  Uri currentUriForCrashReporting;

  Loader(this.target);

  Ticker get ticker => target.ticker;

  LibraryBuilder read(Uri uri) {
    firstSourceUri ??= uri;
    LibraryBuilder builder = builders.putIfAbsent(uri, () {
      LibraryBuilder library = target.createLibraryBuilder(uri);
      if (uri.scheme == "dart" && uri.path == "core") {
        coreLibrary = library;
      }
      first ??= library;
      if (library.loader == this) {
        unparsedLibraries.addLast(library);
      }
      return library;
    });
    return builder;
  }

  void ensureCoreLibrary() {
    if (coreLibrary == null) {
      read(Uri.parse("dart:core"));
      assert(coreLibrary != null);
    }
  }

  Future<Null> buildBodies(AstKind astKind) async {
    assert(coreLibrary != null);
    for (LibraryBuilder library in builders.values) {
      currentUriForCrashReporting = library.uri;
      await buildBody(library, astKind);
    }
    currentUriForCrashReporting = null;
    ticker.log((Duration elapsed, Duration sinceStart) {
      int libraryCount = builders.length;
      double ms =
          elapsed.inMicroseconds / Duration.MICROSECONDS_PER_MILLISECOND;
      String message = "Built $libraryCount compilation units";
      print("""
$sinceStart: $message ($byteCount bytes) in ${format(ms, 3, 0)}ms, that is,
${format(byteCount / ms, 3, 12)} bytes/ms, and
${format(ms / libraryCount, 3, 12)} ms/compilation unit.""");
    });
  }

  Future<Null> buildOutlines() async {
    ensureCoreLibrary();
    while (unparsedLibraries.isNotEmpty) {
      LibraryBuilder library = unparsedLibraries.removeFirst();
      currentUriForCrashReporting = library.uri;
      await buildOutline(library);
    }
    currentUriForCrashReporting = null;
    ticker.log((Duration elapsed, Duration sinceStart) {
      int libraryCount = builders.length;
      double ms =
          elapsed.inMicroseconds / Duration.MICROSECONDS_PER_MILLISECOND;
      String message = "Built outlines for $libraryCount compilation units";
      // TODO(ahe): Share this message with [buildBodies]. Also make it easy to
      // tell the difference between outlines read from a dill file or source
      // files. Currently, [libraryCount] is wrong for dill files.
      print("""
$sinceStart: $message ($byteCount bytes) in ${format(ms, 3, 0)}ms, that is,
${format(byteCount / ms, 3, 12)} bytes/ms, and
${format(ms / libraryCount, 3, 12)} ms/compilation unit.""");
    });
  }

  Future<Null> buildOutline(LibraryBuilder library);

  Future<Null> buildBody(LibraryBuilder library, AstKind astKind);

  List<InputError> collectCompileTimeErrors() {
    List<InputError> errors = <InputError>[];
    for (LibraryBuilder library in builders.values) {
      if (library.loader == this) {
        errors.addAll(library.compileTimeErrors);
      }
    }
    return errors;
  }
}

String format(double d, int fractionDigits, int width) {
  return d.toStringAsFixed(fractionDigits).padLeft(width);
}
