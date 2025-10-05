#!/bin/bash

################################################################################
# Deployment Script for Telegram TOTO Notification Lambda
#
# This script automates the deployment process including:
# - Git workflow (commit, tag, push)
# - Docker image building and pushing to ECR
# - Optional Lambda function update
#
# Usage:
#   ./deploy.sh              # Normal deployment
#   ./deploy.sh --dry-run    # Show what would happen without executing
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Configuration
ECR_REGISTRY="885894375887.dkr.ecr.ap-southeast-1.amazonaws.com"
ECR_REPOSITORY="telegram_toto_notification"
AWS_REGION="ap-southeast-1"
AWS_PROFILE="personal"
LAMBDA_FUNCTION_NAME="telegram_toto_notification"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dry run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}\n"
fi

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Execute command (respecting dry-run mode)
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would execute: $@${NC}"
        return 0
    else
        "$@"
    fi
}

################################################################################
# Validation Functions
################################################################################

check_git_clean() {
    print_header "Checking Git Status"

    if [[ -n $(git status --porcelain) ]]; then
        print_error "Working directory is not clean!"
        echo ""
        git status --short
        echo ""
        print_warning "Please commit or stash your changes before deploying."
        exit 1
    fi

    print_success "Working directory is clean"
}

validate_version() {
    local version=$1
    if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $version"
        print_info "Version must follow semantic versioning (e.g., v0.1.0, v1.2.3)"
        return 1
    fi

    # Check if tag already exists
    if git rev-parse "$version" >/dev/null 2>&1; then
        print_error "Tag $version already exists!"
        return 1
    fi

    return 0
}

check_aws_credentials() {
    print_header "Checking AWS Credentials"

    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$AWS_REGION" >/dev/null 2>&1; then
        print_error "AWS credentials for profile '$AWS_PROFILE' are not valid!"
        exit 1
    fi

    print_success "AWS credentials are valid"
}

check_docker() {
    print_header "Checking Docker"

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running!"
        exit 1
    fi

    print_success "Docker is running"
}

################################################################################
# User Input Functions
################################################################################

get_version() {
    print_header "Version Information"

    # Show recent tags
    echo "Recent versions:"
    git tag -l --sort=-v:refname | head -5 | sed 's/^/  /'
    echo ""

    while true; do
        read -p "Enter new version (e.g., v0.1.0): " VERSION
        if validate_version "$VERSION"; then
            print_success "Version: $VERSION"
            break
        fi
    done
}

get_description() {
    echo ""
    read -p "Enter release description: " DESCRIPTION

    if [[ -z "$DESCRIPTION" ]]; then
        print_error "Description cannot be empty!"
        get_description
    else
        print_success "Description: $DESCRIPTION"
    fi
}

show_summary() {
    print_header "Deployment Summary"

    echo -e "${CYAN}Git:${NC}"
    echo "  Branch:        $(git branch --show-current)"
    echo "  Version:       $VERSION"
    echo "  Description:   $DESCRIPTION"
    echo "  Commit Msg:    Release $VERSION: $DESCRIPTION"
    echo ""
    echo -e "${CYAN}Docker:${NC}"
    echo "  Registry:      $ECR_REGISTRY"
    echo "  Repository:    $ECR_REPOSITORY"
    echo "  Tags:          $VERSION, latest"
    echo ""
    echo -e "${CYAN}AWS:${NC}"
    echo "  Region:        $AWS_REGION"
    echo "  Profile:       $AWS_PROFILE"
    echo "  Lambda:        $LAMBDA_FUNCTION_NAME"
    echo ""

    if [ "$DRY_RUN" = false ]; then
        read -p "Proceed with deployment? (y/N): " -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user"
            exit 0
        fi
    fi
}

################################################################################
# Deployment Functions
################################################################################

create_git_commit_and_tag() {
    print_header "Creating Git Commit and Tag"

    local commit_message="Release $VERSION: $DESCRIPTION"

    # Create commit (with --allow-empty since we're deploying, not changing code)
    print_info "Creating commit: $commit_message"
    execute git commit --allow-empty -m "$commit_message"
    print_success "Commit created"

    # Create tag
    print_info "Creating tag: $VERSION"
    execute git tag -a "$VERSION" -m "Release $VERSION: $DESCRIPTION"
    print_success "Tag created: $VERSION"
}

login_to_ecr() {
    print_header "Logging into ECR"

    print_info "Authenticating with AWS ECR..."
    if [ "$DRY_RUN" = false ]; then
        aws ecr get-login-password --profile "$AWS_PROFILE" --region "$AWS_REGION" | \
            docker login --username AWS --password-stdin "$ECR_REGISTRY" >/dev/null 2>&1
        print_success "Successfully logged into ECR"
    else
        echo -e "${YELLOW}[DRY RUN] Would login to ECR${NC}"
    fi
}

build_docker_image() {
    print_header "Building Docker Image"

    local version_tag="$ECR_REGISTRY/$ECR_REPOSITORY:$VERSION"
    local latest_tag="$ECR_REGISTRY/$ECR_REPOSITORY:latest"

    print_info "Building image with tags:"
    echo "  - $VERSION"
    echo "  - latest"

    execute docker build \
        -t "$version_tag" \
        -t "$latest_tag" \
        .

    print_success "Docker image built successfully"
}

push_docker_images() {
    print_header "Pushing Docker Images to ECR"

    local version_tag="$ECR_REGISTRY/$ECR_REPOSITORY:$VERSION"
    local latest_tag="$ECR_REGISTRY/$ECR_REPOSITORY:latest"

    print_info "Pushing version tag: $VERSION"
    execute docker push "$version_tag"
    print_success "Pushed: $version_tag"

    print_info "Pushing latest tag"
    execute docker push "$latest_tag"
    print_success "Pushed: $latest_tag"
}

push_git_changes() {
    print_header "Pushing Git Changes"

    local current_branch=$(git branch --show-current)

    print_info "Pushing commits to origin/$current_branch"
    execute git push origin "$current_branch"
    print_success "Commits pushed"

    print_info "Pushing tags to origin"
    execute git push origin "$VERSION"
    print_success "Tags pushed"
}

update_lambda_function() {
    print_header "Lambda Function Update"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would ask about Lambda update${NC}"
        return
    fi

    echo "Do you want to update the Lambda function to use the new image?"
    read -p "Update Lambda function? (y/N): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Updating Lambda function: $LAMBDA_FUNCTION_NAME"

        local image_uri="$ECR_REGISTRY/$ECR_REPOSITORY:$VERSION"

        aws lambda update-function-code \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --image-uri "$image_uri" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            > /dev/null

        print_success "Lambda function updated to use: $image_uri"

        print_info "Waiting for Lambda function to be updated..."
        aws lambda wait function-updated \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION"

        print_success "Lambda function is now active with the new image"
    else
        print_info "Skipping Lambda function update"
        echo ""
        print_warning "To update Lambda manually, run:"
        echo -e "${CYAN}aws lambda update-function-code \\"
        echo "  --function-name $LAMBDA_FUNCTION_NAME \\"
        echo "  --image-uri $ECR_REGISTRY/$ECR_REPOSITORY:$VERSION \\"
        echo "  --profile $AWS_PROFILE \\"
        echo "  --region $AWS_REGION${NC}"
    fi
}

################################################################################
# Main Deployment Flow
################################################################################

main() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  Telegram TOTO Notification Lambda Deployment Script     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Pre-flight checks
    check_git_clean
    check_docker
    check_aws_credentials

    # Get deployment information
    get_version
    get_description

    # Show summary and confirm
    show_summary

    # Execute deployment
    create_git_commit_and_tag
    login_to_ecr
    build_docker_image
    push_docker_images
    push_git_changes
    update_lambda_function

    # Success message
    print_header "Deployment Complete!"

    echo -e "${GREEN}✓ Successfully deployed version $VERSION${NC}"
    echo ""
    print_info "Summary:"
    echo "  - Git commit and tag created"
    echo "  - Docker images pushed to ECR"
    echo "  - Git changes pushed to origin"
    echo ""
    print_success "All done!"
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors
trap 'print_error "Deployment failed! Check the error messages above."' ERR

# Run main deployment
main

exit 0
