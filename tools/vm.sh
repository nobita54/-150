#!/bin/bash
set -euo pipefail

# =============================
# Enhanced Multi-VM Manager with TUI
# =============================

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check for required TUI dependencies
check_tui_dependencies() {
    if ! command -v "dialog" &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Dialog is required for the TUI interface"
        echo -e "${BLUE}[INFO]${NC} On Ubuntu/Debian, try: sudo apt install dialog"
        exit 1
    fi
}

# Function to display header
display_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                                                            ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}            ${YELLOW}QEMU Virtual Machine Manager${NC}           ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                 ${GREEN}with Cloud-Init Support${NC}             ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to display colored output
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "INPUT") echo -e "${CYAN}[INPUT]${NC} $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to get all VM configurations
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Clear previous variables
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Function to save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_status "SUCCESS" "Configuration saved to $config_file"
}

# TUI Functions
# =============

# Function to show TUI main menu
show_tui_main_menu() {
    while true; do
        display_header
        
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        # Build menu items
        local menu_items=()
        
        # Always show Create VM first
        menu_items+=("1" "📁 Create New VM")
        
        if [ $vm_count -gt 0 ]; then
            # Show VM count
            echo -e "${CYAN}Available VMs: ${WHITE}$vm_count${NC}\n"
            
            # List VMs with status
            for i in "${!vms[@]}"; do
                local status_indicator="🔴"
                local status_text="Stopped"
                if is_vm_running "${vms[$i]}"; then
                    status_indicator="🟢"
                    status_text="Running"
                fi
                local menu_num=$((i+2))
                menu_items+=("$menu_num" "$status_indicator ${vms[$i]} ($status_text)")
            done
            
            # Add other operations
            local next_num=$((vm_count+2))
            menu_items+=("$next_num" "⚡ Quick Actions")
            menu_items+=("$((next_num+1))" "⚙️  System Info")
            menu_items+=("$((next_num+2))" "❓ Help")
            menu_items+=("0" "🚪 Exit")
        else
            echo -e "${YELLOW}No VMs found. Create your first VM to get started.${NC}\n"
            menu_items+=("2" "⚙️  System Info")
            menu_items+=("3" "❓ Help")
            menu_items+=("0" "🚪 Exit")
        fi
        
        local choice=$(dialog --clear \
            --backtitle "QEMU VM Manager" \
            --title "Main Menu" \
            --menu "Select an option:" \
            24 70 16 \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then
            # User pressed Cancel or ESC
            break
        fi
        
        handle_main_menu_choice "$choice"
    done
}

# Function to handle main menu choices
handle_main_menu_choice() {
    local choice=$1
    local vms=($(get_vm_list))
    local vm_count=${#vms[@]}
    
    case $choice in
        1)
            create_new_vm_tui
            ;;
        *)
            if [ $vm_count -gt 0 ]; then
                if [ "$choice" -le $((vm_count+1)) ]; then
                    # This is a VM selection (choice 2 to vm_count+1)
                    local vm_index=$((choice-2))
                    if [ $vm_index -ge 0 ] && [ $vm_index -lt $vm_count ]; then
                        selected_vm="${vms[$vm_index]}"
                        show_vm_action_menu "$selected_vm"
                    fi
                elif [ "$choice" -eq $((vm_count+2)) ]; then
                    show_quick_actions_menu
                elif [ "$choice" -eq $((vm_count+3)) ]; then
                    show_system_info
                elif [ "$choice" -eq $((vm_count+4)) ]; then
                    show_help
                fi
            else
                case $choice in
                    2) show_system_info ;;
                    3) show_help ;;
                esac
            fi
            ;;
    esac
}

# Function to show VM action menu
show_vm_action_menu() {
    local vm_name="$1"
    
    while true; do
        local status_indicator="🔴"
        local status_text="Stopped"
        if is_vm_running "$vm_name"; then
            status_indicator="🟢"
            status_text="Running"
        fi
        
        local action_choice=$(dialog --clear \
            --backtitle "QEMU VM Manager - $vm_name" \
            --title "VM: $vm_name $status_indicator" \
            --menu "Select action:" \
            18 60 10 \
            "1" "▶️  Start VM" \
            "2" "⏹️  Stop VM" \
            "3" "📊 VM Information" \
            "4" "⚙️  Edit Configuration" \
            "5" "💾 Resize Disk" \
            "6" "📈 Performance" \
            "7" "🗑️  Delete VM" \
            "8" "🔌 SSH Connection" \
            "0" "⬅️  Back" \
            3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then
            break
        fi
        
        case $action_choice in
            1) start_vm_tui "$vm_name" ;;
            2) stop_vm_tui "$vm_name" ;;
            3) show_vm_info_tui "$vm_name" ;;
            4) edit_vm_config_tui "$vm_name" ;;
            5) resize_vm_disk_tui "$vm_name" ;;
            6) show_vm_performance_tui "$vm_name" ;;
            7) delete_vm_tui "$vm_name" ;;
            8) show_ssh_info_tui "$vm_name" ;;
            0) break ;;
        esac
    done
}

# Function to show quick actions menu
show_quick_actions_menu() {
    local vms=($(get_vm_list))
    
    local action_choice=$(dialog --clear \
        --backtitle "QEMU VM Manager - Quick Actions" \
        --title "Quick Actions" \
        --menu "Select action:" \
        15 50 8 \
        "1" "🚀 Start All VMs" \
        "2" "🛑 Stop All VMs" \
        "3" "📋 All VM Status" \
        "4" "📁 Backup All Configs" \
        "0" "⬅️  Back" \
        3>&1 1>&2 2>&3)
    
    case $action_choice in
        1)
            start_all_vms_tui
            ;;
        2)
            stop_all_vms_tui
            ;;
        3)
            show_all_vms_status_tui
            ;;
        4)
            backup_all_configs_tui
            ;;
    esac
}

# Function to show system information
show_system_info() {
    local total_vms=$(get_vm_list | wc -l)
    local running_vms=0
    local vms=($(get_vm_list))
    
    for vm in "${vms[@]}"; do
        if is_vm_running "$vm"; then
            ((running_vms++))
        fi
    done
    
    local info_msg=""
    info_msg+="${CYAN}System Information:${NC}\n"
    info_msg+="────────────────────────────\n"
    info_msg+="${GREEN}• Total VMs:${NC} $total_vms\n"
    info_msg+="${GREEN}• Running VMs:${NC} $running_vms\n"
    info_msg+="${GREEN}• VM Directory:${NC} $VM_DIR\n"
    info_msg+="${GREEN}• Available Disk:${NC} $(df -h "$VM_DIR" | awk 'NR==2 {print $4}')\n"
    info_msg+="${GREEN}• Total Memory:${NC} $(free -h | awk '/^Mem:/ {print $2}')\n"
    info_msg+="${GREEN}• Available Memory:${NC} $(free -h | awk '/^Mem:/ {print $7}')\n"
    info_msg+="${GREEN}• CPU Cores:${NC} $(nproc)\n"
    info_msg+="────────────────────────────\n"
    info_msg+="${YELLOW}Press Enter to continue...${NC}"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - System Info" \
        --title "System Information" \
        --msgbox "$info_msg" \
        16 60
}

# Function to show help
show_help() {
    local help_msg=""
    help_msg+="${CYAN}QEMU VM Manager Help${NC}\n"
    help_msg+="════════════════════════\n\n"
    help_msg+="${GREEN}Navigation:${NC}\n"
    help_msg+="• Use arrow keys to navigate\n"
    help_msg+="• Press Enter to select\n"
    help_msg+="• Press ESC or Cancel to go back\n\n"
    help_msg+="${GREEN}Keyboard Shortcuts:${NC}\n"
    help_msg+="• Tab: Switch between elements\n"
    help_msg+="• Space: Toggle checkboxes\n\n"
    help_msg+="${GREEN}VM Management:${NC}\n"
    help_msg+="• Create VMs from cloud images\n"
    help_msg+="• Auto-configure with cloud-init\n"
    help_msg+="• SSH access with port forwarding\n"
    help_msg+="• GUI or console mode\n\n"
    help_msg+="${GREEN}Requirements:${NC}\n"
    help_msg+="• KVM enabled system\n"
    help_msg+="• Internet connection for downloads\n"
    help_msg+="• Sufficient disk space\n\n"
    help_msg+="${YELLOW}For issues, check logs in ~/vm-manager.log${NC}"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Help" \
        --title "Help & Documentation" \
        --msgbox "$help_msg" \
        20 70
}

# Function to create new VM via TUI
create_new_vm_tui() {
    # Step 1: Select OS
    local os_items=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        os_items+=("$i" "$os")
        ((i++))
    done
    
    local os_choice=$(dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "Select Operating System" \
        --menu "Choose an OS to install:" \
        20 70 12 \
        "${os_items[@]}" \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        return  # User cancelled
    fi
    
    # Get OS details
    local os_names=(${!OS_OPTIONS[@]})
    local selected_os="${os_names[$((os_choice-1))]}"
    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$selected_os]}"
    
    # Step 2: Get VM name
    while true; do
        VM_NAME=$(dialog --clear \
            --backtitle "QEMU VM Manager - Create VM" \
            --title "VM Name" \
            --inputbox "Enter VM name:" \
            10 60 "$DEFAULT_HOSTNAME" \
            3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then return; fi
        
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                dialog --clear \
                    --backtitle "QEMU VM Manager - Create VM" \
                    --title "Error" \
                    --msgbox "VM with name '$VM_NAME' already exists!" \
                    10 60
            else
                break
            fi
        else
            dialog --clear \
                --backtitle "QEMU VM Manager - Create VM" \
                --title "Error" \
                --msgbox "Invalid VM name. Use only letters, numbers, hyphens, and underscores." \
                10 60
        fi
    done
    
    # Step 3: Get other parameters using form
    local form_output=$(dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "VM Configuration" \
        --form "Configure your VM:" \
        20 70 0 \
        "Hostname:" 1 1 "$VM_NAME" 1 20 30 0 \
        "Username:" 2 1 "$DEFAULT_USERNAME" 2 20 30 0 \
        "Password:" 3 1 "$DEFAULT_PASSWORD" 3 20 30 0 \
        "Disk Size (e.g., 20G):" 4 1 "20G" 4 20 30 0 \
        "Memory (MB):" 5 1 "2048" 5 20 30 0 \
        "CPU Cores:" 6 1 "2" 6 20 30 0 \
        "SSH Port:" 7 1 "2222" 7 20 30 0 \
        "Port Forwards (e.g., 8080:80):" 8 1 "" 8 20 30 0 \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Parse form output
    IFS=$'\n' read -rd '' -a form_fields <<< "$form_output"
    HOSTNAME="${form_fields[0]}"
    USERNAME="${form_fields[1]}"
    PASSWORD="${form_fields[2]}"
    DISK_SIZE="${form_fields[3]}"
    MEMORY="${form_fields[4]}"
    CPUS="${form_fields[5]}"
    SSH_PORT="${form_fields[6]}"
    PORT_FORWARDS="${form_fields[7]}"
    
    # GUI mode selection
    dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "GUI Mode" \
        --yesno "Enable GUI mode?\n\nConsole mode recommended for servers." \
        10 60
    
    if [ $? -eq 0 ]; then
        GUI_MODE=true
    else
        GUI_MODE=false
    fi
    
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    # Step 4: Confirmation
    local confirm_msg=""
    confirm_msg+="${CYAN}Please review VM configuration:${NC}\n"
    confirm_msg+="════════════════════════════════\n"
    confirm_msg+="${GREEN}Name:${NC} $VM_NAME\n"
    confirm_msg+="${GREEN}OS:${NC} $selected_os\n"
    confirm_msg+="${GREEN}Hostname:${NC} $HOSTNAME\n"
    confirm_msg+="${GREEN}Username:${NC} $USERNAME\n"
    confirm_msg+="${GREEN}Password:${NC} $PASSWORD\n"
    confirm_msg+="${GREEN}Disk:${NC} $DISK_SIZE\n"
    confirm_msg+="${GREEN}Memory:${NC} $MEMORY MB\n"
    confirm_msg+="${GREEN}CPUs:${NC} $CPUS\n"
    confirm_msg+="${GREEN}SSH Port:${NC} $SSH_PORT\n"
    confirm_msg+="${GREEN}GUI Mode:${NC} $GUI_MODE\n"
    confirm_msg+="${GREEN}Port Forwards:${NC} ${PORT_FORWARDS:-None}\n"
    confirm_msg+="════════════════════════════════\n"
    confirm_msg+="Create this VM?"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "Confirm VM Creation" \
        --yesno "$confirm_msg" \
        18 70
    
    if [ $? -ne 0 ]; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Create VM" \
            --title "Cancelled" \
            --msgbox "VM creation cancelled." \
            10 60
        return
    fi
    
    # Step 5: Download and setup with progress bar
    (
        echo "XXX"
        echo "0"
        echo "Initializing VM creation..."
        echo "XXX"
        sleep 1
        
        echo "XXX"
        echo "20"
        echo "Creating VM directory..."
        echo "XXX"
        mkdir -p "$VM_DIR"
        
        echo "XXX"
        echo "40"
        echo "Downloading OS image..."
        echo "XXX"
        if ! setup_vm_image; then
            echo "XXX"
            echo "100"
            echo "Failed to create VM!"
            echo "XXX"
            sleep 2
            exit 1
        fi
        
        echo "XXX"
        echo "80"
        echo "Saving configuration..."
        echo "XXX"
        save_vm_config
        
        echo "XXX"
        echo "100"
        echo "VM created successfully!"
        echo "XXX"
        sleep 2
    ) | dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "Creating VM" \
        --gauge "Please wait while creating VM..." \
        10 70 0
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Create VM" \
        --title "Success" \
        --msgbox "VM '$VM_NAME' has been created successfully!\n\nSSH: ssh -p $SSH_PORT $USERNAME@localhost\nPassword: $PASSWORD" \
        12 70
}

# Function to setup VM image
setup_vm_image() {
    # Create VM directory if it doesn't exist
    mkdir -p "$VM_DIR"
    
    # Check if image already exists
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image file already exists. Skipping download."
    else
        print_status "INFO" "Downloading image from $IMG_URL..."
        wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp" 2>&1 | \
            grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | \
            awk '{print $2}' | \
            sed -u -e "s,%%,,"
        
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            print_status "ERROR" "Failed to download image from $IMG_URL"
            return 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Resize the disk image if needed
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_status "WARN" "Creating new image with specified size..."
        rm -f "$IMG_FILE"
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
    fi

    # cloud-init configuration
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" user-data meta-data; then
        print_status "ERROR" "Failed to create cloud-init seed image"
        return 1
    fi
    
    return 0
}

# Function to start VM via TUI
start_vm_tui() {
    local vm_name="$1"
    
    if is_vm_running "$vm_name"; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Start VM" \
            --title "Info" \
            --msgbox "VM '$vm_name' is already running!" \
            10 60
        return
    fi
    
    if ! load_vm_config "$vm_name"; then
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Start VM" \
        --title "Start VM" \
        --yesno "Start VM '$vm_name'?\n\nSSH Port: $SSH_PORT\nUsername: $USERNAME" \
        12 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Start VM in background
    (
        # Base QEMU command
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -drive "file=$IMG_FILE,format=qcow2,if=virtio"
            -drive "file=$SEED_FILE,format=raw,if=virtio"
            -boot order=c
            -device virtio-net-pci,netdev=n0
            -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
            -name "$vm_name"
        )

        # Add port forwards if specified
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi

        # Add GUI or console mode
        if [[ "$GUI_MODE" == true ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi

        # Add performance enhancements
        qemu_cmd+=(
            -device virtio-balloon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )

        "${qemu_cmd[@]}" > "$VM_DIR/$vm_name.log" 2>&1 &
    ) &
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Start VM" \
        --title "Success" \
        --msgbox "VM '$vm_name' is starting...\n\nSSH: ssh -p $SSH_PORT $USERNAME@localhost\nPassword: $PASSWORD\n\nCheck logs: $VM_DIR/$vm_name.log" \
        14 70
}

# Function to stop VM via TUI
stop_vm_tui() {
    local vm_name="$1"
    
    if ! is_vm_running "$vm_name"; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Stop VM" \
            --title "Info" \
            --msgbox "VM '$vm_name' is not running." \
            10 60
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Stop VM" \
        --title "Stop VM" \
        --yesno "Stop VM '$vm_name'?" \
        10 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    pkill -f "qemu-system-x86_64.*$vm_name"
    sleep 2
    if is_vm_running "$vm_name"; then
        pkill -9 -f "qemu-system-x86_64.*$vm_name"
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Stop VM" \
        --title "Success" \
        --msgbox "VM '$vm_name' has been stopped." \
        10 60
}

# Function to show VM info via TUI
show_vm_info_tui() {
    local vm_name="$1"
    
    if load_vm_config "$vm_name"; then
        local status_indicator="🔴"
        local status_text="Stopped"
        if is_vm_running "$vm_name"; then
            status_indicator="🟢"
            status_text="Running"
        fi
        
        local info_msg=""
        info_msg+="${CYAN}VM Information: $vm_name $status_indicator${NC}\n"
        info_msg+="════════════════════════════════\n"
        info_msg+="${GREEN}Status:${NC} $status_text\n"
        info_msg+="${GREEN}OS:${NC} $OS_TYPE\n"
        info_msg+="${GREEN}Hostname:${NC} $HOSTNAME\n"
        info_msg+="${GREEN}Username:${NC} $USERNAME\n"
        info_msg+="${GREEN}Password:${NC} $PASSWORD\n"
        info_msg+="${GREEN}SSH Port:${NC} $SSH_PORT\n"
        info_msg+="${GREEN}Memory:${NC} $MEMORY MB\n"
        info_msg+="${GREEN}CPUs:${NC} $CPUS\n"
        info_msg+="${GREEN}Disk:${NC} $DISK_SIZE\n"
        info_msg+="${GREEN}GUI Mode:${NC} $GUI_MODE\n"
        info_msg+="${GREEN}Port Forwards:${NC} ${PORT_FORWARDS:-None}\n"
        info_msg+="${GREEN}Created:${NC} $CREATED\n"
        info_msg+="${GREEN}Image:${NC} $(basename "$IMG_FILE")\n"
        info_msg+="════════════════════════════════\n"
        info_msg+="${YELLOW}SSH Command:${NC}\n"
        info_msg+="ssh -p $SSH_PORT $USERNAME@localhost\n"
        info_msg+="${YELLOW}Password:${NC} $PASSWORD"
        
        dialog --clear \
            --backtitle "QEMU VM Manager - VM Info" \
            --title "VM Information: $vm_name" \
            --msgbox "$info_msg" \
            20 70
    fi
}

# Function to edit VM config via TUI
edit_vm_config_tui() {
    local vm_name="$1"
    
    if ! load_vm_config "$vm_name"; then
        return
    fi
    
    local original_config=""
    original_config+="Hostname=$HOSTNAME\n"
    original_config+="Username=$USERNAME\n"
    original_config+="Password=$PASSWORD\n"
    original_config+="SSH Port=$SSH_PORT\n"
    original_config+="Memory=$MEMORY\n"
    original_config+="CPUs=$CPUS\n"
    original_config+="Disk Size=$DISK_SIZE\n"
    original_config+="Port Forwards=$PORT_FORWARDS"
    
    local form_output=$(dialog --clear \
        --backtitle "QEMU VM Manager - Edit VM" \
        --title "Edit VM Configuration: $vm_name" \
        --form "Edit VM settings:" \
        20 70 0 \
        "Hostname:" 1 1 "$HOSTNAME" 1 20 30 0 \
        "Username:" 2 1 "$USERNAME" 2 20 30 0 \
        "Password:" 3 1 "$PASSWORD" 3 20 30 0 \
        "SSH Port:" 4 1 "$SSH_PORT" 4 20 30 0 \
        "Memory (MB):" 5 1 "$MEMORY" 5 20 30 0 \
        "CPU Cores:" 6 1 "$CPUS" 6 20 30 0 \
        "Disk Size:" 7 1 "$DISK_SIZE" 7 20 30 0 \
        "Port Forwards:" 8 1 "$PORT_FORWARDS" 8 20 30 0 \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Parse form output
    IFS=$'\n' read -rd '' -a form_fields <<< "$form_output"
    HOSTNAME="${form_fields[0]}"
    USERNAME="${form_fields[1]}"
    PASSWORD="${form_fields[2]}"
    SSH_PORT="${form_fields[3]}"
    MEMORY="${form_fields[4]}"
    CPUS="${form_fields[5]}"
    DISK_SIZE="${form_fields[6]}"
    PORT_FORWARDS="${form_fields[7]}"
    
    # GUI mode selection
    dialog --clear \
        --backtitle "QEMU VM Manager - Edit VM" \
        --title "GUI Mode" \
        --yesno "Enable GUI mode for '$vm_name'?\n\nCurrent: $GUI_MODE" \
        10 60
    
    if [ $? -eq 0 ]; then
        GUI_MODE=true
    else
        GUI_MODE=false
    fi
    
    # Save configuration
    save_vm_config
    
    # Recreate seed image if needed
    if [[ "$HOSTNAME" != "$VM_NAME" ]] || [[ "$USERNAME" != "$VM_NAME" ]] || [[ "$PASSWORD" != "$VM_NAME" ]]; then
        setup_vm_image
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Edit VM" \
        --title "Success" \
        --msgbox "VM configuration updated successfully!" \
        10 60
}

# Function to resize VM disk via TUI
resize_vm_disk_tui() {
    local vm_name="$1"
    
    if ! load_vm_config "$vm_name"; then
        return
    fi
    
    local new_size=$(dialog --clear \
        --backtitle "QEMU VM Manager - Resize Disk" \
        --title "Resize Disk: $vm_name" \
        --inputbox "Current size: $DISK_SIZE\nEnter new disk size (e.g., 50G):" \
        12 60 "" \
        3>&1 1>&2 2>&3)
    
    if [ $? -ne 0 ] || [ -z "$new_size" ]; then
        return
    fi
    
    if ! validate_input "size" "$new_size"; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Resize Disk" \
            --title "Error" \
            --msgbox "Invalid disk size format. Use format like 20G, 100G, etc." \
            10 60
        return
    fi
    
    if [[ "$new_size" == "$DISK_SIZE" ]]; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Resize Disk" \
            --title "Info" \
            --msgbox "New size is same as current size. No changes made." \
            10 60
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Resize Disk" \
        --title "Confirm Resize" \
        --yesno "Resize disk from $DISK_SIZE to $new_size?\n\nWARNING: Shrinking may cause data loss!" \
        12 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    (
        echo "XXX"
        echo "0"
        echo "Resizing disk..."
        echo "XXX"
        
        if qemu-img resize "$IMG_FILE" "$new_size"; then
            DISK_SIZE="$new_size"
            save_vm_config
            echo "XXX"
            echo "100"
            echo "Disk resized successfully!"
            echo "XXX"
            sleep 2
        else
            echo "XXX"
            echo "100"
            echo "Failed to resize disk!"
            echo "XXX"
            sleep 2
        fi
    ) | dialog --clear \
        --backtitle "QEMU VM Manager - Resize Disk" \
        --title "Resizing Disk" \
        --gauge "Please wait..." \
        10 70 0
}

# Function to show VM performance via TUI
show_vm_performance_tui() {
    local vm_name="$1"
    
    if ! load_vm_config "$vm_name"; then
        return
    fi
    
    local perf_msg=""
    perf_msg+="${CYAN}Performance: $vm_name${NC}\n"
    perf_msg+="════════════════════════════════\n"
    
    if is_vm_running "$vm_name"; then
        # Get QEMU process info
        local qemu_pid=$(pgrep -f "qemu-system-x86_64.*$vm_name")
        if [ -n "$qemu_pid" ]; then
            perf_msg+="${GREEN}Process ID:${NC} $qemu_pid\n"
            perf_msg+="${GREEN}Process Info:${NC}\n"
            perf_msg+="$(ps -p "$qemu_pid" -o pid,%cpu,%mem,sz,rss,vsz --no-headers)\n\n"
        fi
        
        perf_msg+="${GREEN}System Memory:${NC}\n"
        perf_msg+="$(free -h | sed 's/^/  /')\n\n"
        
        perf_msg+="${GREEN}Disk Usage:${NC}\n"
        perf_msg+="$(df -h "$IMG_FILE" 2>/dev/null || echo "  Not available")\n"
    else
        perf_msg+="${YELLOW}VM is not running${NC}\n\n"
        perf_msg+="${GREEN}Configured Resources:${NC}\n"
        perf_msg+="• Memory: $MEMORY MB\n"
        perf_msg+="• CPUs: $CPUS\n"
        perf_msg+="• Disk: $DISK_SIZE\n"
    fi
    
    perf_msg+="════════════════════════════════"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Performance" \
        --title "Performance: $vm_name" \
        --msgbox "$perf_msg" \
        20 70
}

# Function to delete VM via TUI
delete_vm_tui() {
    local vm_name="$1"
    
    if is_vm_running "$vm_name"; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Delete VM" \
            --title "Error" \
            --msgbox "Cannot delete running VM '$vm_name'.\nStop the VM first." \
            10 60
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Delete VM" \
        --title "Delete VM" \
        --yesno "WARNING: This will permanently delete VM '$vm_name' and all its data!\n\nAre you sure?" \
        12 60
    
    if [ $? -ne 0 ]; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Delete VM" \
            --title "Cancelled" \
            --msgbox "VM deletion cancelled." \
            10 60
        return
    fi
    
    if load_vm_config "$vm_name"; then
        rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf" "$VM_DIR/$vm_name.log" 2>/dev/null
        
        dialog --clear \
            --backtitle "QEMU VM Manager - Delete VM" \
            --title "Success" \
            --msgbox "VM '$vm_name' has been deleted successfully!" \
            10 60
    fi
}

# Function to show SSH info via TUI
show_ssh_info_tui() {
    local vm_name="$1"
    
    if ! load_vm_config "$vm_name"; then
        return
    fi
    
    local ssh_info=""
    ssh_info+="${CYAN}SSH Connection: $vm_name${NC}\n"
    ssh_info+="════════════════════════════════\n\n"
    ssh_info+="${GREEN}Command:${NC}\n"
    ssh_info+="ssh -p $SSH_PORT $USERNAME@localhost\n\n"
    ssh_info+="${GREEN}Password:${NC} $PASSWORD\n\n"
    ssh_info+="${GREEN}Additional Info:${NC}\n"
    ssh_info+="• Username: $USERNAME\n"
    ssh_info+="• Hostname: $HOSTNAME\n"
    ssh_info+="• Port: $SSH_PORT\n\n"
    ssh_info+="${YELLOW}Note:${NC} Make sure the VM is running before connecting."
    
    dialog --clear \
        --backtitle "QEMU VM Manager - SSH Info" \
        --title "SSH Connection: $vm_name" \
        --msgbox "$ssh_info" \
        16 70
}

# Function to start all VMs via TUI
start_all_vms_tui() {
    local vms=($(get_vm_list))
    local total=${#vms[@]}
    local to_start=()
    
    for vm in "${vms[@]}"; do
        if ! is_vm_running "$vm"; then
            to_start+=("$vm")
        fi
    done
    
    local start_count=${#to_start[@]}
    
    if [ $start_count -eq 0 ]; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Start All" \
            --title "Info" \
            --msgbox "All VMs are already running!" \
            10 60
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Start All" \
        --title "Start All VMs" \
        --yesno "Start all $start_count stopped VMs?" \
        10 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    (
        echo "XXX"
        echo "0"
        echo "Starting VMs..."
        echo "XXX"
        
        local i=0
        for vm in "${to_start[@]}"; do
            start_vm_tui "$vm" >/dev/null 2>&1 &
            ((i++))
            echo "XXX"
            echo $((i * 100 / start_count))
            echo "Starting: $vm"
            echo "XXX"
            sleep 1
        done
        
        echo "XXX"
        echo "100"
        echo "All VMs started!"
        echo "XXX"
        sleep 2
    ) | dialog --clear \
        --backtitle "QEMU VM Manager - Start All" \
        --title "Starting All VMs" \
        --gauge "Please wait..." \
        10 70 0
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Start All" \
        --title "Success" \
        --msgbox "Started $start_count VM(s) in the background." \
        10 60
}

# Function to stop all VMs via TUI
stop_all_vms_tui() {
    local vms=($(get_vm_list))
    local running_vms=()
    
    for vm in "${vms[@]}"; do
        if is_vm_running "$vm"; then
            running_vms+=("$vm")
        fi
    done
    
    local running_count=${#running_vms[@]}
    
    if [ $running_count -eq 0 ]; then
        dialog --clear \
            --backtitle "QEMU VM Manager - Stop All" \
            --title "Info" \
            --msgbox "No VMs are currently running." \
            10 60
        return
    fi
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Stop All" \
        --title "Stop All VMs" \
        --yesno "Stop all $running_count running VMs?" \
        10 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    pkill -f "qemu-system-x86_64"
    sleep 2
    pkill -9 -f "qemu-system-x86_64" 2>/dev/null
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Stop All" \
        --title "Success" \
        --msgbox "Stopped all $running_count VM(s)." \
        10 60
}

# Function to show all VMs status via TUI
show_all_vms_status_tui() {
    local vms=($(get_vm_list))
    local total=${#vms[@]}
    local running=0
    
    for vm in "${vms[@]}"; do
        if is_vm_running "$vm"; then
            ((running++))
        fi
    done
    
    local status_msg=""
    status_msg+="${CYAN}VM Status Overview${NC}\n"
    status_msg+="════════════════════════════════\n\n"
    status_msg+="${GREEN}Total VMs:${NC} $total\n"
    status_msg+="${GREEN}Running:${NC} $running\n"
    status_msg+="${GREEN}Stopped:${NC} $((total - running))\n\n"
    
    if [ $total -gt 0 ]; then
        status_msg+="${YELLOW}Individual VM Status:${NC}\n"
        for vm in "${vms[@]}"; do
            if is_vm_running "$vm"; then
                status_msg+="🟢 $vm\n"
            else
                status_msg+="🔴 $vm\n"
            fi
        done
    else
        status_msg+="${YELLOW}No VMs found.${NC}"
    fi
    
    status_msg+="\n════════════════════════════════"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Status" \
        --title "All VM Status" \
        --msgbox "$status_msg" \
        20 60
}

# Function to backup all configs via TUI
backup_all_configs_tui() {
    local backup_dir="$VM_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Backup" \
        --title "Backup Configurations" \
        --yesno "Backup all VM configurations to:\n$backup_dir\n\nProceed?" \
        12 60
    
    if [ $? -ne 0 ]; then
        return
    fi
    
    (
        echo "XXX"
        echo "0"
        echo "Creating backup directory..."
        echo "XXX"
        mkdir -p "$backup_dir"
        
        echo "XXX"
        echo "50"
        echo "Copying configuration files..."
        echo "XXX"
        cp "$VM_DIR"/*.conf "$backup_dir/" 2>/dev/null || true
        
        echo "XXX"
        echo "100"
        echo "Backup completed!"
        echo "XXX"
        sleep 2
    ) | dialog --clear \
        --backtitle "QEMU VM Manager - Backup" \
        --title "Backup in Progress" \
        --gauge "Please wait..." \
        10 70 0
    
    local file_count=$(ls -1 "$backup_dir"/*.conf 2>/dev/null | wc -l)
    
    dialog --clear \
        --backtitle "QEMU VM Manager - Backup" \
        --title "Backup Complete" \
        --msgbox "Backup completed successfully!\n\nLocation: $backup_dir\nFiles backed up: $file_count" \
        12 60
}

# Function to check if VM is running
is_vm_running() {
    local vm_name=$1
    if pgrep -f "qemu-system-x86_64.*$vm_name" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies
check_tui_dependencies

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/vms}"
mkdir -p "$VM_DIR"

# Supported OS list
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# Start the TUI
show_tui_main_menu

# Clean exit
echo -e "${GREEN}[INFO]${NC} Goodbye!"
exit 0
