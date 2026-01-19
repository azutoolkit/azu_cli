#!/bin/bash
# AZU CLI Codebase Analyzer
# Scans and analyzes azu_cli for framework pattern compliance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE="${1:-$HOME/azu-workspace}"
REPORT_FILE="${WORKSPACE}/analysis_report.md"

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Initialize workspace
init_workspace() {
    print_header "Initializing AZU Analysis Workspace"
    
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE"
    
    # Clone repositories if not present
    for repo in azu_cli azu cql joobq; do
        if [ ! -d "$repo" ]; then
            print_section "Cloning $repo..."
            git clone "https://github.com/azutoolkit/${repo}.git" 2>/dev/null || {
                print_error "Failed to clone $repo"
                return 1
            }
        else
            print_success "$repo already present"
        fi
    done
}

# Analyze azu_cli structure
analyze_structure() {
    print_header "Analyzing AZU CLI Structure"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "## AZU CLI Structure Analysis" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Directory Structure" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    find . -type f \( -name "*.cr" -o -name "*.ecr" \) | grep -v ".git" | sort >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Count files
    cr_files=$(find . -name "*.cr" | wc -l)
    ecr_files=$(find . -name "*.ecr" | wc -l)
    
    print_success "Crystal files: $cr_files"
    print_success "Template files: $ecr_files"
    
    echo "### File Counts" >> "$REPORT_FILE"
    echo "- Crystal source files: $cr_files" >> "$REPORT_FILE"
    echo "- ECR template files: $ecr_files" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Analyze templates
analyze_templates() {
    print_header "Analyzing Templates"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "### Template Analysis" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Find all templates
    print_section "Scanning template files..."
    
    templates=$(find . -name "*.ecr" 2>/dev/null || echo "")
    
    if [ -z "$templates" ]; then
        print_warning "No ECR templates found"
        echo "⚠️ No ECR templates found" >> "$REPORT_FILE"
    else
        echo "#### Template Files Found" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "$templates" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        # Analyze each template
        for template in $templates; do
            echo "##### $template" >> "$REPORT_FILE"
            echo '```crystal' >> "$REPORT_FILE"
            head -50 "$template" >> "$REPORT_FILE" 2>/dev/null || echo "Unable to read"
            echo '```' >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        done
    fi
}

# Check for AZU pattern compliance
check_azu_compliance() {
    print_header "Checking AZU Pattern Compliance"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "### AZU Pattern Compliance" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for Azu::Endpoint usage
    print_section "Checking for Azu::Endpoint pattern..."
    endpoint_refs=$(grep -rn "Azu::Endpoint\|< Azu::Endpoint" . 2>/dev/null | wc -l || echo "0")
    echo "- Azu::Endpoint references: $endpoint_refs" >> "$REPORT_FILE"
    
    # Check for proper request/response types
    print_section "Checking for Request/Response types..."
    request_refs=$(grep -rn "Azu::Request\|< Azu::Request" . 2>/dev/null | wc -l || echo "0")
    response_refs=$(grep -rn "Azu::Response\|< Azu::Response" . 2>/dev/null | wc -l || echo "0")
    echo "- Azu::Request references: $request_refs" >> "$REPORT_FILE"
    echo "- Azu::Response references: $response_refs" >> "$REPORT_FILE"
    
    # Check for HTTP::Handler (old pattern)
    print_section "Checking for deprecated patterns..."
    http_handler=$(grep -rn "HTTP::Handler\|HTTP::Server" . 2>/dev/null | wc -l || echo "0")
    if [ "$http_handler" -gt 0 ]; then
        print_warning "Found $http_handler deprecated HTTP::Handler references"
        echo "- ⚠️ Deprecated HTTP::Handler references: $http_handler" >> "$REPORT_FILE"
    else
        print_success "No deprecated HTTP patterns found"
        echo "- ✓ No deprecated HTTP patterns" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Check for CQL pattern compliance
check_cql_compliance() {
    print_header "Checking CQL Pattern Compliance"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "### CQL Pattern Compliance" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for CQL::Model usage
    print_section "Checking for CQL::Model pattern..."
    model_refs=$(grep -rn "CQL::Model\|< CQL::Model" . 2>/dev/null | wc -l || echo "0")
    echo "- CQL::Model references: $model_refs" >> "$REPORT_FILE"
    
    # Check for migration patterns
    print_section "Checking for migration patterns..."
    migration_refs=$(grep -rn "CQL::Migration\|< CQL::Migration" . 2>/dev/null | wc -l || echo "0")
    echo "- CQL::Migration references: $migration_refs" >> "$REPORT_FILE"
    
    # Check for repository patterns
    print_section "Checking for repository patterns..."
    repo_refs=$(grep -rn "CQL::Repository\|< CQL::Repository" . 2>/dev/null | wc -l || echo "0")
    echo "- CQL::Repository references: $repo_refs" >> "$REPORT_FILE"
    
    echo "" >> "$REPORT_FILE"
}

# Check for JOOBQ pattern compliance
check_joobq_compliance() {
    print_header "Checking JOOBQ Pattern Compliance"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "### JOOBQ Pattern Compliance" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for Joobq::Job usage
    print_section "Checking for Joobq::Job pattern..."
    job_refs=$(grep -rn "Joobq::Job\|include Joobq::Job" . 2>/dev/null | wc -l || echo "0")
    echo "- Joobq::Job references: $job_refs" >> "$REPORT_FILE"
    
    # Check for queue configuration
    print_section "Checking for queue configuration..."
    queue_refs=$(grep -rn 'queue "' . 2>/dev/null | wc -l || echo "0")
    echo "- Queue configuration references: $queue_refs" >> "$REPORT_FILE"
    
    echo "" >> "$REPORT_FILE"
}

# Extract patterns from reference frameworks
extract_framework_patterns() {
    print_header "Extracting Framework Patterns"
    
    echo "### Framework Pattern Extraction" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # AZU patterns
    if [ -d "$WORKSPACE/azu/src" ]; then
        print_section "Extracting AZU patterns..."
        echo "#### AZU Key Classes" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -rn "^class\|^module\|^struct\|^abstract" "$WORKSPACE/azu/src" 2>/dev/null | head -30 >> "$REPORT_FILE" || echo "Unable to extract"
        echo '```' >> "$REPORT_FILE"
    fi
    
    # CQL patterns
    if [ -d "$WORKSPACE/cql/src" ]; then
        print_section "Extracting CQL patterns..."
        echo "#### CQL Key Classes" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -rn "^class\|^module\|^struct\|^abstract" "$WORKSPACE/cql/src" 2>/dev/null | head -30 >> "$REPORT_FILE" || echo "Unable to extract"
        echo '```' >> "$REPORT_FILE"
    fi
    
    # JOOBQ patterns
    if [ -d "$WORKSPACE/joobq/src" ]; then
        print_section "Extracting JOOBQ patterns..."
        echo "#### JOOBQ Key Classes" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -rn "^class\|^module\|^struct\|^abstract" "$WORKSPACE/joobq/src" 2>/dev/null | head -30 >> "$REPORT_FILE" || echo "Unable to extract"
        echo '```' >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Identify issues and anti-patterns
identify_issues() {
    print_header "Identifying Issues and Anti-Patterns"
    
    cd "$WORKSPACE/azu_cli"
    
    echo "### Issues and Anti-Patterns" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Hardcoded values
    print_section "Checking for hardcoded values..."
    hardcoded=$(grep -rn "localhost\|127.0.0.1\|:3000\|:5432" . 2>/dev/null | grep -v ".git" | wc -l || echo "0")
    if [ "$hardcoded" -gt 0 ]; then
        print_warning "Found $hardcoded hardcoded values"
        echo "#### Hardcoded Values" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -rn "localhost\|127.0.0.1\|:3000\|:5432" . 2>/dev/null | grep -v ".git" | head -20 >> "$REPORT_FILE" || true
        echo '```' >> "$REPORT_FILE"
    fi
    
    # Missing type annotations
    print_section "Checking for missing type annotations..."
    missing_types=$(grep -rn "def .*)" . 2>/dev/null | grep -v ":" | grep "\.cr:" | wc -l || echo "0")
    if [ "$missing_types" -gt 0 ]; then
        print_warning "Found $missing_types potential missing type annotations"
        echo "#### Potential Missing Type Annotations" >> "$REPORT_FILE"
        echo "Found $missing_types methods potentially missing return type annotations" >> "$REPORT_FILE"
    fi
    
    # TODO/FIXME comments
    print_section "Checking for TODO/FIXME comments..."
    todos=$(grep -rn "TODO\|FIXME\|XXX\|HACK" . 2>/dev/null | grep -v ".git" | wc -l || echo "0")
    if [ "$todos" -gt 0 ]; then
        print_warning "Found $todos TODO/FIXME comments"
        echo "#### TODO/FIXME Comments" >> "$REPORT_FILE"
        echo '```' >> "$REPORT_FILE"
        grep -rn "TODO\|FIXME\|XXX\|HACK" . 2>/dev/null | grep -v ".git" | head -20 >> "$REPORT_FILE" || true
        echo '```' >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Generate recommendations
generate_recommendations() {
    print_header "Generating Recommendations"
    
    echo "### Recommendations" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    cat >> "$REPORT_FILE" << 'EOF'
#### Priority 1: Critical (Must Fix)
1. Update all endpoint templates to use `Azu::Endpoint` pattern
2. Update model templates to use `CQL::Model` pattern
3. Update job templates to use `Joobq::Job` pattern

#### Priority 2: Important (Should Fix)
1. Add proper type annotations to all methods
2. Remove hardcoded values, use environment variables
3. Add comprehensive error handling patterns

#### Priority 3: Enhancement (Nice to Have)
1. Add interactive prompts for better DX
2. Improve help text and documentation
3. Add validation and feedback mechanisms

#### Next Steps
1. Review each template file in detail
2. Compare with reference framework patterns
3. Create updated templates
4. Test generated code against framework specs
5. Document changes and update CLI help
EOF
    
    echo "" >> "$REPORT_FILE"
}

# Main execution
main() {
    print_header "AZU CLI Analysis Tool"
    echo "Workspace: $WORKSPACE"
    echo ""
    
    # Initialize report
    echo "# AZU CLI Analysis Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Run analysis steps
    init_workspace
    analyze_structure
    analyze_templates
    check_azu_compliance
    check_cql_compliance
    check_joobq_compliance
    extract_framework_patterns
    identify_issues
    generate_recommendations
    
    print_header "Analysis Complete"
    print_success "Report saved to: $REPORT_FILE"
    echo ""
    echo "To view the report:"
    echo "  cat $REPORT_FILE"
}

# Run main
main "$@"
