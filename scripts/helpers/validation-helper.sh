#!/bin/bash

# Validation helper functions

validate_project_name() {
    local name="$1"

    if [[ ! "$name" =~ ^[a-z_][a-z0-9_]*$ ]]; then
        print_error "Invalid project name."
        print_info "Project name must:"
        print_info "  - Start with lowercase letter or underscore"
        print_info "  - Contain only lowercase letters, numbers, and underscores"
        print_info "  - Example: my_awesome_app"
        exit 1
    fi

    print_success "Project name is valid"
}

validate_organization() {
    local org="$1"

    if [[ ! "$org" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$ ]]; then
        print_error "Invalid organization format."
        print_info "Organization must be in reverse domain format:"
        print_info "  - Example: com.mycompany"
        print_info "  - Example: com.github.username"
        exit 1
    fi

    print_success "Organization is valid"
}

validate_github_repo() {
    local repo="$1"

    if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid GitHub repository format."
        print_info "Format should be: username/repository-name"
        print_info "  - Example: johndoe/my-awesome-app"
        exit 1
    fi

    print_success "GitHub repository format is valid"
}

check_command() {
    local cmd="$1"
    local name="$2"

    if ! command -v "$cmd" &> /dev/null; then
        print_error "$name is not installed!"
        print_info "Please install $name: https://docs.flutter.dev/get-started/install"
        exit 1
    fi

    local version=""
    case "$cmd" in
        flutter)
            version=$(flutter --version 2>/dev/null | head -1 | awk '{print $2}')
            ;;
        node)
            version=$(node --version 2>/dev/null)
            ;;
        *)
            version="installed"
            ;;
    esac

    print_success "$name: $version"
}

check_command_optional() {
    local cmd="$1"
    local name="$2"

    if command -v "$cmd" &> /dev/null; then
        print_success "$name is installed"
        return 0
    else
        print_warning "$name is not installed (optional)"
        return 1
    fi
}

check_directory_empty() {
    local dir="$1"

    if [ -d "$dir" ] && [ "$(ls -A "$dir")" ]; then
        return 1
    else
        return 0
    fi
}

check_git_repository() {
    if [ -d ".git" ]; then
        return 0
    else
        return 1
    fi
}
