#!/bin/sh

set -eu

developer_dir=$(/usr/bin/xcode-select -p)
testing_frameworks="$developer_dir/Library/Developer/Frameworks"
testing_libraries="$developer_dir/Library/Developer/usr/lib"
testing_macros="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

if [ -f "$testing_macros" ] \
    && [ -d "$testing_frameworks/Testing.framework" ] \
    && [ -f "$testing_libraries/lib_TestingInterop.dylib" ]; then
    exec /usr/bin/swift test \
        -Xswiftc -load-plugin-library \
        -Xswiftc "$testing_macros" \
        -Xlinker -rpath \
        -Xlinker "$testing_frameworks" \
        -Xlinker -rpath \
        -Xlinker "$testing_libraries"
fi

exec /usr/bin/swift test
