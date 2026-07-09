cd ~/dev/AWS-EKS-Hardened-Infrastructure

# 2. รันคำสั่งนี้จากจุดศูนย์กลาง เพื่อกวาดทุกโฟลเดอร์ย่อยมาไว้ที่นี่ไฟล์เดียว

find . -type f \( -name "*.tf" -o -name "*.tfvars" -o -name "*.yaml" -o -name "*.yml" -o -name "*.cfg" -o -name "*.ign" \) -not -path "*/.*" | while read -r file; do
    echo -e "\n========================================="
    echo "📄 FILE: $file"
    echo -e "=========================================\n"
    cat "$file"
done > ULTIMATE_MASTER_CODE.txt
