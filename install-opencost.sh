#!/bin/bash

set -e

# OpenCost Installation Script
# This script installs OpenCost using Helm or Kubernetes manifests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="opencost"
INSTALLATION_METHOD="helm"
INSTALL_PROMETHEUS=false
VALUES_FILE=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --method METHOD     Installation method: 'helm' or 'manifest' (default: helm)"
    echo "  -n, --namespace NAME    Kubernetes namespace (default: opencost)"
    echo "  -p, --prometheus        Install Prometheus (only with helm method)"
    echo "  -f, --values-file FILE  Custom Helm values file"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Install with Helm using defaults"
    echo "  $0 -m manifest                       # Install using Kubernetes manifests"
    echo "  $0 -p                                # Install with Helm and Prometheus"
    echo "  $0 -f custom-values.yaml             # Install with custom Helm values"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if helm is installed (only for helm method)
    if [ "$INSTALLATION_METHOD" = "helm" ]; then
        if ! command -v helm &> /dev/null; then
            print_error "Helm is not installed. Please install Helm first or use manifest method."
            exit 1
        fi
    fi
    
    print_success "Prerequisites check passed"
}

# Function to install Prometheus
install_prometheus() {
    print_info "Installing Prometheus..."
    
    # Create prometheus namespace if it doesn't exist
    kubectl create namespace prometheus-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus with OpenCost scrape configs
    helm install prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
        --namespace prometheus-system \
        --set prometheus-pushgateway.enabled=false \
        --set alertmanager.enabled=false \
        -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml
    
    print_success "Prometheus installed successfully"
}

# Function to install OpenCost using Helm
install_with_helm() {
    print_info "Installing OpenCost using Helm..."
    
    # Add OpenCost Helm repository
    helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
    helm repo update
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Prepare helm install command
    HELM_CMD="helm install opencost opencost-charts/opencost --namespace $NAMESPACE"
    
    # Add values file if specified
    if [ -n "$VALUES_FILE" ]; then
        if [ -f "$VALUES_FILE" ]; then
            HELM_CMD="$HELM_CMD -f $VALUES_FILE"
        else
            print_error "Values file '$VALUES_FILE' not found"
            exit 1
        fi
    fi
    
    # Execute helm install
    eval $HELM_CMD
    
    print_success "OpenCost installed successfully using Helm"
}

# Function to install OpenCost using Kubernetes manifests
install_with_manifest() {
    print_info "Installing OpenCost using Kubernetes manifests..."
    
    # Apply the OpenCost manifest
    kubectl apply -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/opencost.yaml
    
    print_success "OpenCost installed successfully using Kubernetes manifests"
}

# Function to verify installation
verify_installation() {
    print_info "Verifying OpenCost installation..."
    
    # Wait for pods to be ready
    print_info "Waiting for OpenCost pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opencost -n "$NAMESPACE" --timeout=300s
    
    # Check pod status
    print_info "OpenCost pod status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=opencost
    
    # Get service information
    print_info "OpenCost service information:"
    kubectl get svc -n "$NAMESPACE"
    
    print_success "OpenCost installation verification completed"
}

# Function to show access information
show_access_info() {
    print_info "Access OpenCost UI:"
    echo ""
    echo "To access OpenCost UI, run:"
    echo "  kubectl port-forward --namespace $NAMESPACE deployment/opencost 9003:9003"
    echo ""
    echo "Then open your browser and navigate to: http://localhost:9003"
    echo ""
    echo "API endpoint will be available at: http://localhost:9003/model"
}

# Main installation function
main() {
    print_info "Starting OpenCost installation..."
    print_info "Installation method: $INSTALLATION_METHOD"
    print_info "Namespace: $NAMESPACE"
    
    check_prerequisites
    
    # Install Prometheus if requested and using Helm
    if [ "$INSTALL_PROMETHEUS" = true ]; then
        if [ "$INSTALLATION_METHOD" = "helm" ]; then
            install_prometheus
        else
            print_warning "Prometheus installation is only supported with Helm method"
        fi
    fi
    
    # Install OpenCost based on selected method
    case $INSTALLATION_METHOD in
        "helm")
            install_with_helm
            ;;
        "manifest")
            install_with_manifest
            ;;
        *)
            print_error "Invalid installation method: $INSTALLATION_METHOD"
            usage
            exit 1
            ;;
    esac
    
    verify_installation
    show_access_info
    
    print_success "OpenCost installation completed successfully!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--method)
            INSTALLATION_METHOD="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--prometheus)
            INSTALL_PROMETHEUS=true
            shift
            ;;
        -f|--values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate installation method
if [[ "$INSTALLATION_METHOD" != "helm" && "$INSTALLATION_METHOD" != "manifest" ]]; then
    print_error "Installation method must be 'helm' or 'manifest'"
    usage
    exit 1
fi

# Run main function
main