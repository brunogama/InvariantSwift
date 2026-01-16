# XCTest (default behavior)
./run_sigtrap_capture.sh MyPackage
./run_sigtrap_capture.sh MyPackage "MyTestClass/testMethod"

# Swift Testing
./run_sigtrap_capture.sh MyPackage --swift-testing
./run_sigtrap_capture.sh MyPackage "MyTests/testSuspiciousFunction" --swift-testing
./run_sigtrap_capture.sh MyPackage --swift-testing  # all Swift Testing tests
