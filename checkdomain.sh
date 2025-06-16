#!/bin/bash

# รับชื่อโดเมนจาก argument หรือถามผู้ใช้
DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    read -p "กรุณาใส่ชื่อโดเมนที่ต้องการตรวจสอบ: " DOMAIN
fi

LOGFILE="domain-check.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# เช็ก WHOIS
WHOIS_RESULT=$(whois "$DOMAIN")

echo "===== [$TIMESTAMP] WHOIS Result for $DOMAIN ====="
echo "$WHOIS_RESULT"
echo "=================================================="

# ดึงวันหมดอายุ
EXPIRY_RAW=$(echo "$WHOIS_RESULT" | grep -iE 'Expiry Date:|Expiration Date:' | head -n1 | awk '{print $NF}' | cut -d. -f1)

# แปลงวันหมดอายุเป็น timestamp
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS ใช้ date -j
    EXPIRY_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$EXPIRY_RAW" +%s 2>/dev/null)
else
    # Linux ใช้ date -d
    EXPIRY_EPOCH=$(date -d "$EXPIRY_RAW" +%s 2>/dev/null)
fi

# วันปัจจุบัน
NOW_EPOCH=$(date +%s)

# ตรวจสอบสถานะ
if echo "$WHOIS_RESULT" | grep -qEi "Domain Status:.*pendingDelete"; then
    if [ -n "$EXPIRY_EPOCH" ]; then
        DAYS_PASSED=$(( (NOW_EPOCH - EXPIRY_EPOCH) / 86400 ))
        LEFT_TILL_DROP=$((75 - DAYS_PASSED))
        if [[ "$OSTYPE" == "darwin"* ]]; then
            DROP_DATE=$(date -j -r $((EXPIRY_EPOCH + 75*86400)) "+%Y-%m-%d")
        else
            DROP_DATE=$(date -d "@$((EXPIRY_EPOCH + 75*86400))" "+%Y-%m-%d")
        fi
        echo "$TIMESTAMP ⚠️ Domain is in pendingDelete period ($DAYS_PASSED วันหลังหมดอายุ), คาดว่าจะหลุดให้จดใหม่ได้ภายใน $LEFT_TILL_DROP วัน (ประมาณ $DROP_DATE)" | tee -a "$LOGFILE"
    else
        echo "$TIMESTAMP ⚠️ Domain is in pendingDelete period (ไม่สามารถคำนวณวันหมดอายุได้): $DOMAIN" | tee -a "$LOGFILE"
    fi
elif echo "$WHOIS_RESULT" | grep -qEi "No match for|NOT FOUND|Domain not found"; then
    echo "$TIMESTAMP ✅ Domain is AVAILABLE! => $DOMAIN" | tee -a "$LOGFILE"
else
    if [ -n "$EXPIRY_EPOCH" ]; then
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
        if [[ "$OSTYPE" == "darwin"* ]]; then
            DROP_DATE=$(date -j -r $((EXPIRY_EPOCH + 75*86400)) "+%Y-%m-%d")
        else
            DROP_DATE=$(date -d "@$((EXPIRY_EPOCH + 75*86400))" "+%Y-%m-%d")
        fi

        if [ "$DAYS_LEFT" -gt 0 ]; then
            echo "$TIMESTAMP ❌ Domain still NOT available: $DOMAIN (จะหมดอายุในอีก $DAYS_LEFT วัน)" | tee -a "$LOGFILE"
        else
            DAYS_PASSED=$(( (NOW_EPOCH - EXPIRY_EPOCH) / 86400 ))
            LEFT_TILL_DROP=$((75 - DAYS_PASSED))
            echo "$TIMESTAMP ⚠️ Domain expired $DAYS_PASSED วันแล้ว, คาดว่าจะหลุดให้จดใหม่ได้ภายใน $LEFT_TILL_DROP วัน (ประมาณ $DROP_DATE)" | tee -a "$LOGFILE"
        fi
    else
        echo "$TIMESTAMP ❌ Domain still NOT available: $DOMAIN (ไม่พบวันหมดอายุใน WHOIS)" | tee -a "$LOGFILE"
    fi
fi