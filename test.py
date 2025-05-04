import plistlib

# Đọc file nhị phân
with open("ImportedBackups.plist", "rb") as f:
    data = plistlib.load(f)

# Ghi ra file XML
with open("Converted_ImportedBackups.xml", "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_XML)

print("✅ Đã chuyển xong sang XML")
