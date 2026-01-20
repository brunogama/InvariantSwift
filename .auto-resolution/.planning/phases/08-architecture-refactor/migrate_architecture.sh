#!/bin/bash
# InvariantSwift Architecture Migration Script
# Run from the package root directory
#
# Usage:
#   ./migrate_architecture.sh --dry-run    # Preview changes
#   ./migrate_architecture.sh --execute    # Actually perform migration
#   ./migrate_architecture.sh --verify     # Check migration status

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PACKAGE_ROOT="$(pwd)"
SOURCES_DIR="${PACKAGE_ROOT}/Sources"
DRY_RUN=true

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
case "${1:-}" in
  --dry-run)
    DRY_RUN=true
    log_info "Running in DRY-RUN mode - no changes will be made"
    ;;
  --execute)
    DRY_RUN=false
    log_warning "Running in EXECUTE mode - changes will be made!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
    ;;
  --verify)
    verify_migration
    exit 0
    ;;
  *)
    echo "Usage: $0 [--dry-run|--execute|--verify]"
    exit 1
    ;;
esac

# Helper: Create directory if needed
ensure_dir() {
  local dir="$1"
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Would create directory: $dir"
  else
    mkdir -p "$dir"
    log_success "Created directory: $dir"
  fi
}

# Helper: Move file
move_file() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$src" ]]; then
    log_warning "Source file does not exist: $src"
    return 1
  fi
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Would move: $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    log_success "Moved: $src → $dst"
  fi
}

# Helper: Copy file (for safety during migration)
copy_file() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$src" ]]; then
    log_warning "Source file does not exist: $src"
    return 1
  fi
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Would copy: $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log_success "Copied: $src → $dst"
  fi
}

# Helper: Create umbrella file
create_umbrella() {
  local path="$1"
  local content="$2"
  if [[ "$DRY_RUN" == true ]]; then
    log_info "Would create umbrella: $path"
    echo "  Content: $content"
  else
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    log_success "Created umbrella: $path"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 1: Create new directory structure
# ═══════════════════════════════════════════════════════════════════════

phase1_create_directories() {
  log_info "=== PHASE 1: Creating directory structure ==="

  ensure_dir "${SOURCES_DIR}/InvariantSwiftCore"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftGenerators"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExecution"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftPersistence"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftMacroAPI"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Advanced"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Coverage"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Extensions"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Fuzzing"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Observability"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftExperimental/Reliability"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftTesting"
  ensure_dir "${SOURCES_DIR}/InvariantSwiftMacroImpl"
  ensure_dir "${SOURCES_DIR}/GhostwriterSyntax"
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 2: Copy Core files
# ═══════════════════════════════════════════════════════════════════════

phase2_copy_core() {
  log_info "=== PHASE 2: Copying Core files ==="

  local CORE_SRC="${SOURCES_DIR}/InvariantSwift/Core"
  local CORE_DST="${SOURCES_DIR}/InvariantSwiftCore"

  # Core files staying in Core
  local CORE_FILES=(
    "AnyCodable.swift"
    "AnySendable.swift"
    "BusinessRuleViolation.swift"
    "ClassificationContext.swift"
    "ClassificationReport.swift"
    "ClassifyingProperty.swift"
    "ClassifyingPropertyRunner.swift"
    "FailingExample.swift"
    "FailureReport.swift"
    "ForAll.swift"
    "Gen.swift"
    "Generatable.swift"
    "Generator+String.swift"
    "GeneratorConstraint.swift"
    "ModelTesting.swift"
    "Property+Classification.swift"
    "Property+Combinators.swift"
    "Property+Implication.swift"
    "Property.swift"
    "PropertyConfig+Helpers.swift"
    "PropertyExecution.swift"
    "PropertyResult+Extensions.swift"
    "PropertyTimeout.swift"
    "RuleBasedStateMachine.swift"
    "RunReport.swift"
    "RunReportBuilder.swift"
    "Seed.swift"
    "Shrink.swift"
    "ShrinkTree+Parallel.swift"
    "ShrinkTree.swift"
    "SizeType.swift"
  )

  for file in "${CORE_FILES[@]}"; do
    copy_file "${CORE_SRC}/${file}" "${CORE_DST}/${file}"
  done

  # Files moving to Execution
  local EXEC_DST="${SOURCES_DIR}/InvariantSwiftExecution"
  copy_file "${CORE_SRC}/IsolatedPropertyRunner.swift" "${EXEC_DST}/IsolatedPropertyRunner.swift"
  copy_file "${CORE_SRC}/PropertyRunner+Discard.swift" "${EXEC_DST}/PropertyRunner+Discard.swift"
  copy_file "${CORE_SRC}/PropertyRunner+Progress.swift" "${EXEC_DST}/PropertyRunner+Progress.swift"
  copy_file "${CORE_SRC}/SubprocessIsolation.swift" "${EXEC_DST}/SubprocessIsolation.swift"

  # Files moving to Persistence
  local PERSIST_DST="${SOURCES_DIR}/InvariantSwiftPersistence"
  copy_file "${CORE_SRC}/ExampleDatabase.swift" "${PERSIST_DST}/ExampleDatabase.swift"
  copy_file "${CORE_SRC}/RegressionBank.swift" "${PERSIST_DST}/RegressionBank.swift"
  copy_file "${CORE_SRC}/ReplayToken.swift" "${PERSIST_DST}/ReplayToken.swift"
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 3: Copy Generators
# ═══════════════════════════════════════════════════════════════════════

phase3_copy_generators() {
  log_info "=== PHASE 3: Copying Generator files ==="

  local GEN_SRC="${SOURCES_DIR}/InvariantSwift/Generators"
  local GEN_DST="${SOURCES_DIR}/InvariantSwiftGenerators"

  local GEN_FILES=(
    "CollectionGenerators.swift"
    "CombinatorGenerators.swift"
    "FloatingPointMode.swift"
    "Generatable+Primitives.swift"
    "NumericGenerators.swift"
    "OptionalResultGenerators.swift"
    "PrimitiveGenerators.swift"
  )

  for file in "${GEN_FILES[@]}"; do
    copy_file "${GEN_SRC}/${file}" "${GEN_DST}/${file}"
  done
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 4: Copy Testing files
# ═══════════════════════════════════════════════════════════════════════

phase4_copy_testing() {
  log_info "=== PHASE 4: Copying Testing/Execution files ==="

  local TEST_SRC="${SOURCES_DIR}/InvariantSwift/Testing"
  local EXEC_DST="${SOURCES_DIR}/InvariantSwiftExecution"

  local TEST_FILES=(
    "ConfigBuilder.swift"
    "ConfigTemplate.swift"
    "GeneratorTestHelpers.swift"
    "TargetCollector.swift"
    "TargetedConfig.swift"
    "TargetedRunner.swift"
    "TargetedTesting.swift"
  )

  for file in "${TEST_FILES[@]}"; do
    copy_file "${TEST_SRC}/${file}" "${EXEC_DST}/${file}"
  done
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 5: Copy Database files
# ═══════════════════════════════════════════════════════════════════════

phase5_copy_database() {
  log_info "=== PHASE 5: Copying Database files ==="

  local DB_SRC="${SOURCES_DIR}/InvariantSwift/Database"
  local DB_DST="${SOURCES_DIR}/InvariantSwiftPersistence"

  copy_file "${DB_SRC}/CorpusDatabase.swift" "${DB_DST}/CorpusDatabase.swift"
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 6: Copy Macro declarations
# ═══════════════════════════════════════════════════════════════════════

phase6_copy_macro_api() {
  log_info "=== PHASE 6: Copying Macro API declarations ==="

  local MACRO_SRC="${SOURCES_DIR}/InvariantSwift/Macros"
  local MACRO_DST="${SOURCES_DIR}/InvariantSwiftMacroAPI"

  if [[ -d "$MACRO_SRC" ]]; then
    for file in "${MACRO_SRC}"/*.swift; do
      if [[ -f "$file" ]]; then
        copy_file "$file" "${MACRO_DST}/$(basename "$file")"
      fi
    done
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 7: Copy SwiftTesting files
# ═══════════════════════════════════════════════════════════════════════

phase7_copy_swift_testing() {
  log_info "=== PHASE 7: Copying Swift Testing integration files ==="

  local ST_SRC="${SOURCES_DIR}/InvariantSwift/SwiftTesting"
  local ST_DST="${SOURCES_DIR}/InvariantSwiftTesting"

  local ST_FILES=(
    "ExpectDifference.swift"
    "FailurePersistence.swift"
    "FailureReporting.swift"
    "PropertyTestIntegration.swift"
    "TestStatistics.swift"
  )

  for file in "${ST_FILES[@]}"; do
    copy_file "${ST_SRC}/${file}" "${ST_DST}/${file}"
  done
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 8: Copy Experimental files
# ═══════════════════════════════════════════════════════════════════════

phase8_copy_experimental() {
  log_info "=== PHASE 8: Copying Experimental files ==="

  local EXP_DST="${SOURCES_DIR}/InvariantSwiftExperimental"

  # Advanced
  local ADV_SRC="${SOURCES_DIR}/InvariantSwift/Advanced"
  if [[ -d "$ADV_SRC" ]]; then
    for file in "${ADV_SRC}"/*.swift; do
      if [[ -f "$file" ]]; then
        copy_file "$file" "${EXP_DST}/Advanced/$(basename "$file")"
      fi
    done
  fi

  # Coverage
  copy_file "${SOURCES_DIR}/InvariantSwift/Coverage/ClassificationCoverage.swift" "${EXP_DST}/Coverage/ClassificationCoverage.swift"

  # Extensions
  local EXT_SRC="${SOURCES_DIR}/InvariantSwift/Extensions"
  if [[ -d "$EXT_SRC" ]]; then
    for file in "${EXT_SRC}"/*.swift; do
      if [[ -f "$file" ]]; then
        copy_file "$file" "${EXP_DST}/Extensions/$(basename "$file")"
      fi
    done
  fi

  # Fuzzing
  copy_file "${SOURCES_DIR}/InvariantSwift/Fuzzing/LibFuzzerIntegration.swift" "${EXP_DST}/Fuzzing/LibFuzzerIntegration.swift"

  # Observability
  copy_file "${SOURCES_DIR}/InvariantSwift/Observability/TelemetrySystem.swift" "${EXP_DST}/Observability/TelemetrySystem.swift"

  # Reliability
  local REL_SRC="${SOURCES_DIR}/InvariantSwift/Reliability"
  if [[ -d "$REL_SRC" ]]; then
    for file in "${REL_SRC}"/*.swift; do
      if [[ -f "$file" ]]; then
        copy_file "$file" "${EXP_DST}/Reliability/$(basename "$file")"
      fi
    done
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 9: Rename directories
# ═══════════════════════════════════════════════════════════════════════

phase9_rename_directories() {
  log_info "=== PHASE 9: Renaming directories ==="

  # Rename InvariantSwiftMacros → InvariantSwiftMacroImpl
  local MACRO_OLD="${SOURCES_DIR}/InvariantSwiftMacros"
  local MACRO_NEW="${SOURCES_DIR}/InvariantSwiftMacroImpl"

  if [[ -d "$MACRO_OLD" && ! -d "$MACRO_NEW" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log_info "Would rename: $MACRO_OLD → $MACRO_NEW"
    else
      # Copy instead of rename to preserve original during migration
      cp -r "$MACRO_OLD" "$MACRO_NEW"
      log_success "Copied: $MACRO_OLD → $MACRO_NEW"
    fi
  fi

  # Rename GhostwriterLib → GhostwriterSyntax
  local GW_OLD="${SOURCES_DIR}/GhostwriterLib"
  local GW_NEW="${SOURCES_DIR}/GhostwriterSyntax"

  if [[ -d "$GW_OLD" && ! -d "$GW_NEW" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log_info "Would rename: $GW_OLD → $GW_NEW"
    else
      # Copy instead of rename to preserve original during migration
      cp -r "$GW_OLD" "$GW_NEW"
      log_success "Copied: $GW_OLD → $GW_NEW"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# PHASE 10: Create umbrella files
# ═══════════════════════════════════════════════════════════════════════

phase10_create_umbrellas() {
  log_info "=== PHASE 10: Creating umbrella files ==="

  # InvariantSwiftCore - no re-exports (it's the base)
  create_umbrella "${SOURCES_DIR}/InvariantSwiftCore/InvariantSwiftCore.swift" \
'// InvariantSwiftCore - Base types for property-based testing
// This module has ZERO external dependencies

// All public types are defined in this module:
// - Gen<T>, Shrink<T>, ShrinkTree<T>
// - Property, PropertyConfig, PropertyResult
// - Seed, Size
// - ForAll, Generatable'

  # InvariantSwiftGenerators
  create_umbrella "${SOURCES_DIR}/InvariantSwiftGenerators/InvariantSwiftGenerators.swift" \
'// InvariantSwiftGenerators - Generator implementations
@_exported import InvariantSwiftCore'

  # InvariantSwiftExecution
  create_umbrella "${SOURCES_DIR}/InvariantSwiftExecution/InvariantSwiftExecution.swift" \
'// InvariantSwiftExecution - Property test runners and configuration
@_exported import InvariantSwiftCore'

  # InvariantSwiftPersistence
  create_umbrella "${SOURCES_DIR}/InvariantSwiftPersistence/InvariantSwiftPersistence.swift" \
'// InvariantSwiftPersistence - Example database and regression storage
@_exported import InvariantSwiftCore'

  # InvariantSwiftMacroAPI
  create_umbrella "${SOURCES_DIR}/InvariantSwiftMacroAPI/InvariantSwiftMacroAPI.swift" \
'// InvariantSwiftMacroAPI - Macro declarations (NO swift-syntax dependency!)
@_exported import InvariantSwiftCore
@_exported import InvariantSwift'

  # InvariantSwiftExperimental
  create_umbrella "${SOURCES_DIR}/InvariantSwiftExperimental/InvariantSwiftExperimental.swift" \
'// InvariantSwiftExperimental - Advanced and experimental features
@_exported import InvariantSwiftCore
@_exported import InvariantSwift'

  # InvariantSwiftTesting
  create_umbrella "${SOURCES_DIR}/InvariantSwiftTesting/InvariantSwiftTesting.swift" \
'// InvariantSwiftTesting - Swift Testing framework integration
@_exported import InvariantSwiftCore
@_exported import InvariantSwift
@_exported import InvariantSwiftExperimental
@_exported import InvariantSwiftMacroAPI'
}

# ═══════════════════════════════════════════════════════════════════════
# VERIFY: Check migration status
# ═══════════════════════════════════════════════════════════════════════

verify_migration() {
  log_info "=== Verifying migration status ==="

  local EXPECTED_DIRS=(
    "InvariantSwiftCore"
    "InvariantSwiftGenerators"
    "InvariantSwiftExecution"
    "InvariantSwiftPersistence"
    "InvariantSwiftMacroAPI"
    "InvariantSwiftExperimental"
    "InvariantSwiftTesting"
    "InvariantSwiftMacroImpl"
    "GhostwriterSyntax"
  )

  local missing=0
  for dir in "${EXPECTED_DIRS[@]}"; do
    if [[ -d "${SOURCES_DIR}/${dir}" ]]; then
      local count
      count=$(find "${SOURCES_DIR}/${dir}" -name "*.swift" | wc -l | tr -d ' ')
      log_success "${dir}: ${count} Swift files"
    else
      log_error "${dir}: MISSING"
      ((missing++))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_success "All expected directories exist!"
  else
    log_error "${missing} directories are missing"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════

main() {
  log_info "Starting InvariantSwift architecture migration..."
  log_info "Package root: ${PACKAGE_ROOT}"

  phase1_create_directories
  phase2_copy_core
  phase3_copy_generators
  phase4_copy_testing
  phase5_copy_database
  phase6_copy_macro_api
  phase7_copy_swift_testing
  phase8_copy_experimental
  phase9_rename_directories
  phase10_create_umbrellas

  log_info "=== Migration Complete ==="

  if [[ "$DRY_RUN" == true ]]; then
    log_warning "This was a DRY RUN. No files were actually changed."
    log_info "Run with --execute to perform the migration."
  else
    log_success "Migration executed successfully!"
    log_info "Next steps:"
    echo "  1. Update Package.swift with new target definitions"
    echo "  2. Update import statements in moved files"
    echo "  3. Run: swift build"
    echo "  4. Run: swift test"
    echo "  5. Once verified, remove original files"
  fi
}

main
