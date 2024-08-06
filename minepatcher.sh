#!/bin/bash

cd $HOME

# Setup storage permission for Termux if necessary
directory="$HOME/storage"
if [ -d "$directory" ]; then
    echo -e "Termux's storage is already setup, skipping storage setup."
else
    termux-setup-storage
fi

apt update && apt upgrade -y

# Check and setup dependencies
declare -A packages
packages=(
  ["java"]="openjdk-17"
  ["dialog"]="dialog"
  ["curl"]="curl"
  ["unzip"]="unzip"
)

for cmdname in "${!packages[@]}"
do
    if ! command -v ${cmdname} &> /dev/null
    then
        echo "Installing ${cmdname}"
        apt install -y ${packages[$cmdname]}
        if [ $? -ne 0 ]; then
            echo "Failed to install ${cmdname}"
            exit 1
        fi
    else
        echo "${cmdname} is already installed"
    fi
done

# Find all APK files having "Minecraft" (case insensitive) in file name from /storage/emulated/0/Download
clear
echo "Searching for Minecraft APK in Download Folder..."
mapfile -t files < <(find /storage/emulated/0/Download -type f -iname '*minecraft*.apk' | sort -f)
    
if [ ${#files[@]} -eq 0 ]; then
    echo "ERROR: No APK files with 'Minecraft' in filename found in Download folder."
    exit 1
else
    options=()
    for i in "${!files[@]}"; do
        display_name="${files[i]#/storage/emulated/0/Download/}"
        options+=($((i+1)) "$display_name" off)
    done
    
    height=$(($(stty size | awk '{print $1}') - 4))
    width=$(($(stty size | awk '{print $2}') - 4))
    list_height=$((height - 5))
    
    choice=$(dialog --no-shadow --title "-:APK Selection:-" --radiolist "Please select the Minecraft APK file from Download folder for patching:" ${height} ${width} ${list_height} "${options[@]}" 3>&1 1>&2 2>&3 3>&-)
    clear
    
    if [ -n "$choice" ]; then
        apkpath="${files[choice-1]}"
    else
        echo "ERROR: No Minecraft APK selected."
        exit 1
    fi
fi

# Move the apk file to home directory for faster execution
mv "${apkpath}" "${HOME}"

# Store the new location of the apk file into a variable
newpath=${HOME}/$(basename "$apkpath")

# Patches selection screen
patches=("Renderdragon Shaders" "Old Storage Path" "Patched UI" "No License Check" "No Swear Filter Client" "No Vanilla Music" "ESSL100 Renderer")

dialog_patches=()
index=1
for patch in "${patches[@]}"; do
    dialog_patches+=("$index" "$patch" "off")
    ((index++))
done

choices=$(dialog --stdout --no-shadow --title "-:Patches Selection:-" --checklist "Select Patches:" 17 42 7 "${dialog_patches[@]}")
clear

if [[ -z "$choices" ]]; then
    echo "ERROR: No patches selected."
    exit 1
fi

chosen_patches=()
for choice in $choices; do
    index=$((choice-1))
    chosen_patches+=("${patches[index]}")
done

# Display confirmation dialog
dialog --no-shadow --title "-:Confirm App Info Edit:-" --yesno "Do you want to edit App Info?" 7 45
response=$?
clear

# Assign yes to result if yes, no if no
if [ $response -eq 0 ]; then
    result="yes"
else
    result="no"
fi

# Take necessary info if result is yes
if [ "$result" == "yes" ]; then
    clear
    echo "Searching for icon png in Download Folder..."
    # Find all .png files containing "icon" in their name (case insensitive) in /storage/emulated/0/Download
    mapfile -t icons < <(find /storage/emulated/0/Download -type f -iname '*icon*.png' | sort -f)

    # Check if any icons found
    if [ ${#icons[@]} -gt 0 ]; then
        options=()
        for i in "${!icons[@]}"; do
            display_name="${icons[i]#/storage/emulated/0/Download/}"
            options+=($((i+1)) "$display_name" off)
        done

        height=$(($(stty size | awk '{print $1}') - 4))
        width=$(($(stty size | awk '{print $2}') - 4))
        list_height=$((height - 5))

        # Display the selection dialog
        icon=$(dialog --no-shadow --title "Select App Icon" --radiolist "Choose an icon:" ${height} ${width} ${list_height} "${options[@]}" 3>&1 1>&2 2>&3 3>&-)
        clear
        
        # Get the chosen icon or ] to the default icon
        if [ -n "$icon" ]; then
            icon_path="${icons[icon-1]}"
        else
            icon_path="default"
        fi
    else
        icon_path="default"
    fi

    # Get app name from the user
    dialog --no-shadow --title "App Name" --inputbox "Enter the App Name:" 8 40 2>app_name
    clear
    if [ -z "$app_name" ]; then
        app_name="Minecraft"
    fi

    # Get package name from the user
    dialog --no-shadow --title "Package Name" --inputbox "Enter the Package Name:" 8 40 2>package_name
    clear
    if [ -z "$package_name" ]; then
        package_name="com.mojang.minecraftpe"
    fi
fi
# Start logging
exec > >(tee -i $HOME/patch.log) 2>&1

# Display selected APK file path
echo -e "\nUsing the following selected APK file:-"
echo -e "$apkpath\n"

# Display chosen patches
echo "Using the following selected patches:-"
for patch in "${chosen_patches[@]}"; do
    echo "$patch"
done

# Display app info edit confirmation and related info
if [ "$result" == "yes" ]; then
    # Output the results
    echo -e "\nEdit App Info: $result"
    echo -e "Icon Path: $icon_path"
    echo -e "App Name: $app_name"
    echo -e "Package Name: $package_name"
else
    echo -e "\nEdit App Info: $result"
fi

sleep 3

# Example call to the insert function
# insert "path/to/text" "search_string" "text_to_insert" line_offset

# Example call to the replace function
# replace "path/to/text" "search_string" "replacement_string" line_offset

# Example call to the scan version function
# scan_android_manifest "path/to/AndroidManifest.xml"

# Define a function to check the group of game version
scan_android_manifest() {
    local manifest_file=$1

    if [[ ! -f "$manifest_file" ]]; then
        echo "Error: File not found!"
        return 1
    fi

    local version_line
    local version_number
    local major minor patch

    # Extract the line containing the version name
    version_line=$(grep 'android:versionName=' "$manifest_file")
    
    if [[ $version_line =~ android:versionName=\"([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        version_number=${BASH_REMATCH[1]}
    else
        echo "Error: Version name not found!"
        return 1
    fi

    # Split the version number into major, minor, and patch parts
    IFS='.' read -r major minor patch <<< "$version_number"

    echo "Detected version: $version_number"

    # Exit the function if the version is less than the specified version
    if [[ $major -eq 0 || ($major -eq 1 && $minor -lt 18) || ($major -eq 1 && $minor -eq 18 && $patch -lt 20) ]]; then
        echo "This game version does not have the renderdragon engine."
        return 1 && exec > /dev/tty 2>&1 && mv $HOME/patch.log /storage/emulated/0/Download
    fi
    
    # Use case statement to determine the version range and print corresponding info
    case "$major.$minor.$patch" in
        1.18.20 | 1.18.3[0-3] | 1.19.[0-2] | 1.19.1[0-1] | 1.19.2[0-2] | 1.19.3[0-1] | 1.19.4[0-1] | 1.19.5[0-1])
            echo "Version is in range: 1.18.30 - 1.19.51"
            ver_grp=0
            ;;
        1.19.6[0-3] | 1.19.7[0-3] | 1.19.8[0-3] | 1.20.[0-1] | 1.20.1[0-5] | 1.20.20 | 1.20.3[0-2] | 1.20.4[0-1] | 1.20.5[0-1] | 1.20.6[0-2] | 1.20.7[0-3])
            echo "Version is in range: 1.19.60 - 1.20.73"
            ver_grp=1
            ;;
        1.20.8[0-1] | 1.21.[0-3] | 1.21.10)
            echo "Version is in range: 1.20.80 - 1.21.2, 1.21.10"
            ver_grp=2
            ;;
        *)
            echo "Version is in range: 1.21.20 or newer."
            ver_grp=3
            ;;
    esac
}

# Define a function to replace strings in text files
replace() {
    local TEXT_FILE="$1"
    local SEARCH_STRING="$2"
    local REPLACEMENT_STRING="$3"
    local LINE_OFFSET="$4"

    if [ ! -f "$TEXT_FILE" ]; then
        echo "Error: Text file does not exist."
        return 1
    fi

    replace_text() {
        local file="$1"
        local line_number="$2"
        local text="$3"

        original_line=$(sed "${line_number}q;d" "$file")
        echo "Replacing line in $file at line $line_number: '$original_line' -> '$text'"

        tmp_file=$(mktemp)
        awk -v n="$line_number" -v s="$text" 'NR == n {print s; next} {print}' "$file" > "$tmp_file"
        mv "$tmp_file" "$file"
    }

    grep -n "$SEARCH_STRING" "$TEXT_FILE" | while IFS=: read -r line_number line_content; do
        target_line_number=$((line_number + LINE_OFFSET))
        if [ "$target_line_number" -le 0 ]; then
            echo "Warning: Target line number $target_line_number is out of range for $TEXT_FILE"
            continue
        fi
        replace_text "$TEXT_FILE" "$target_line_number" "$REPLACEMENT_STRING"
    done

    echo "Replaced text successfully."
}

# Define a function to insert strings in text files
insert() {
    local TEXT_FILE="$1"
    local SEARCH_STRING="$2"
    local TEXT_TO_INSERT="$3"
    local LINE_OFFSET="$4"

    if [ ! -f "$TEXT_FILE" ]; then
        echo "Error: Text file does not exist."
        return 1
    fi

    insert_text() {
        local file="$1"
        local line_number="$2"
        local text="$3"

        tmp_file=$(mktemp)
        awk -v n="$line_number" -v s="$text" 'NR == n {print s} {print}' "$file" > "$tmp_file"
        mv "$tmp_file" "$file"
    }

    grep -n "$SEARCH_STRING" "$TEXT_FILE" | while IFS=: read -r line_number line_content; do
        target_line_number=$((line_number + LINE_OFFSET))

        if [ "$target_line_number" -le 0 ]; then
            echo "Warning: Target line number $target_line_number is out of range for $TEXT_FILE"
            continue
        fi

        echo "Inserting text into $TEXT_FILE at line $target_line_number"
        insert_text "$TEXT_FILE" "$target_line_number" "$TEXT_TO_INSERT"
    done

    echo "Inserted text successfully."
}

# Determine device architecture
arch=$(uname -m)

# Download rsapksign tar based on device architecture
case "$arch" in
    aarch64 | arm64)
        curl -L -o rsapksign.tar.gz https://github.com/mcbegamerxx954/rsapksign/releases/download/v0.1.1/rsapksign-aarch64-linux-android.tar.gz
        ;;
    armv7l | arm | armv8l | arm32)
        curl -L -o rsapksign.tar.gz https://github.com/mcbegamerxx954/rsapksign/releases/download/v0.1.1/rsapksign-armv7-linux-androideabi.tar.gz
        ;;
    x86_64)
        curl -L -o rsapksign.tar.gz https://github.com/mcbegamerxx954/rsapksign/releases/download/v0.1.1/rsapksign-x86_64-unknown-linux-gnu.tar.gz
        ;;
    *)
        echo "Unsupported architecture: $arch"
        exec > /dev/tty 2>&1 && mv $HOME/patch.log /storage/emulated/0/Download && exit 1
        ;;
esac

tar xvfz rsapksign.tar.gz

# Download apkeditor jar and rsapksign binary
curl -L -o apkeditor.jar https://github.com/REAndroid/APKEditor/releases/download/V1.3.9/APKEditor-1.3.9.jar

# Decompile apk file
java -jar apkeditor.jar d -i ${newpath}
decomp="${newpath%.apk}_decompile_xml"

# Apply patches based on user selection
for patch in "${chosen_patches[@]}"; do
    case "$patch" in
        "Renderdragon Shaders")
            echo "Applying 'Renderdragon Shaders' patch..."
            insert "${decomp}/smali/classes/com/mojang/minecraftpe/MainActivity.smali" ".method public onCreate(Landroid/os/Bundle;)V" "\n.method public native dracoSetupStorage()V\n.end method" -1
            insert "${decomp}/smali/classes/com/mojang/minecraftpe/MainActivity.smali" ".method public onCreate(Landroid/os/Bundle;)V" "\n    const-string v0, \"mcbe_r\"\n\n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n\n    invoke-virtual {p0}, Lcom/mojang/minecraftpe/MainActivity;->dracoSetupStorage()V" 16
            # Detect directories and download corresponding files
            for dir in "${decomp}/root/lib"/*; do
            case "$(basename "$dir")" in
                "arm64-v8a")
                curl -L -o "$dir/libmcbe_r.so" "https://github.com/mcbegamerxx954/mcbe_shader_redirector/releases/download/v0.1.8/libmcbe_r_aarch64-linux-android.so"
                ;;
                "armeabi-v7a")
                curl -L -o "$dir/libmcbe_r.so" "https://github.com/mcbegamerxx954/mcbe_shader_redirector/releases/download/v0.1.8/libmcbe_r_armv7-linux-androideabi.so"
                ;;
                "x86_64")
                curl -L -o "$dir/libmcbe_r.so" "https://github.com/mcbegamerxx954/mcbe_shader_redirector/releases/download/v0.1.8/libmcbe_r_x86_64-linux-android.so"
                ;;
                "x86")
                curl -L -o "$dir/libmcbe_r.so" "https://github.com/mcbegamerxx954/mcbe_shader_redirector/releases/download/v0.1.8/libmcbe_r_i686-linux-android.so"
                ;;
            esac
            done
            ;;
        "Old Storage Path")
            echo "Applying 'Old Storage Path' patch..."
            replace "${decomp}/smali/classes/com/mojang/minecraftpe/MainActivity.smali" ".method public getExternalStoragePath()Ljava/lang/String;" "    invoke-static {}, Landroid/os/Environment;->getExternalStorageDirectory()Ljava/io/File;" 5
            replace "${decomp}/smali/classes/com/mojang/minecraftpe/MainActivity.smali" ".method public getInternalStoragePath()Ljava/lang/String;" "    invoke-static {}, Landroid/os/Environment;->getExternalStorageDirectory()Ljava/io/File;" 3
            insert "${decomp}/AndroidManifest.xml" "  <uses-permission android:name=\"android.permission.WRITE_EXTERNAL_STORAGE\" />" "  <uses-permission android:name=\"android.permission.MANAGE_EXTERNAL_STORAGE\" />" 1
            ;;
        "Patched UI")
            echo "Applying 'Patched UI' patch..."
            curl https://raw.githubusercontent.com/CallMeSoumya2063/MinePatcher/main/title.png > ${decomp}/root/assets/assets/resource_packs/vanilla/textures/ui/title.png
            replace "${decomp}/root/assets/assets/resource_packs/vanilla/ui/start_screen.json" "  \"development_version\": {" "          \"text\": \"Patched with MinePatcher\"," 8
            replace "${decomp}/root/assets/assets/resource_packs/vanilla/ui/start_screen.json" "  \"text_panel\": {" "" 12
            ;;
        "No License Check")
            echo "Applying 'No License Check' patch..."
            replace "${decomp}/smali/classes/com/mojang/minecraftpe/store/googleplay/GooglePlayStore.smali" ".method public hasVerifiedLicense()Z" "    const v0,0x1" 3
            ;;
        "No Swear Filter Client")
            echo "Applying 'No Swear Filter Client' patch..."
            rm ${decomp}/root/assets/assets/profanity_filter.wlist
            touch ${decomp}/root/assets/assets/profanity_filter.wlist
            ;;
        "No Vanilla Music")
            echo "Applying 'No Vanilla Music' patch..."
            rm -rf ${decomp}/root/assets/assets/resource_packs/vanilla_music
            ;;
        "ESSL100 Renderer")
            scan_android_manifest ${decomp}/AndroidManifest.xml
            case "$ver_grp" in
                0)
                    echo "'ESSL100 Renderer' patch is not applicable for detected game version."
                    ;;
                1)
                    echo "Applying 'ESSL100 Renderer' patch for 1.19.60 - 1.20.73 ..."
                    curl https://raw.githubusercontent.com/CallMeSoumya2063/MinePatcher/main/1.20.73ESSL_100_onlyfix_lag.mcpack > $HOME/v1_essl100.zip
                    unzip -o $HOME/v1_essl100.zip 'renderer/materials/*' -d ${decomp}/root/assets/assets/renderer/materials && rm $HOME/v1_essl100.zip
                    ;;
                2)
                    echo "Applying 'ESSL100 Renderer' patch for 1.20.80 - 1.21.10 ..."
                    curl https://raw.githubusercontent.com/CallMeSoumya2063/MinePatcher/main/1.20.81-ESSL_100.mcpack > $HOME/v2_essl100.zip
                    unzip -o $HOME/v2_essl100.zip 'renderer/materials/*' -d ${decomp}/root/assets/assets/renderer/materials && rm $HOME/v2_essl100.zip
                    ;;
                3)
                    echo "Applying 'ESSL100 Renderer' patch for 1.21.20 or newer ..."
                    curl https://raw.githubusercontent.com/CallMeSoumya2063/MinePatcher/main/essl100_1.21.20.mcpack > $HOME/v3_essl100.zip
                    unzip -o $HOME/v3_essl100.zip 'renderer/materials/*' -d ${decomp}/root/assets/assets/renderer/materials && rm $HOME/v3_essl100.zip
                    ;;
            esac
            ;;
    esac
done

echo "All selected patches have been applied."

# Compile and sign app, and/or edit app info based on 'Confirm App Info Edit'
if [ "$result" == "yes" ]; then
    if [[ "$icon_path" != *"default"* ]]; then
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-xhdpi/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-xxhdpi/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-xxxhdpi/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-hdpi/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-mdpi/icon.png"
        cp -f "${icon_path}" "${decomp}/resources/package_1/res/drawable-ldpi/icon.png"
    else
        echo "Default app icon will be used."
    fi
    java -jar apkeditor.jar b -i "${decomp}"
    ./rsapksign -p "${package_name}" -a "${app_name}" -o "$(dirname "$apkpath")/PATCHED-$(basename "$apkpath")" "${decomp}_out.apk"
    mv "${newpath}" "${apkpath}"
    rm -rf "${decomp}_out.apk" "${decomp}" apkeditor.jar rsapksign rsapksign.tar.gz
else
    java -jar apkeditor.jar b -i "${decomp}"
    ./rsapksign -o "$(dirname "$apkpath")/PATCHED-$(basename "$apkpath")" "${decomp}_out.apk"
    mv "${newpath}" "${apkpath}"
    rm -rf "${decomp}_out.apk" "${decomp}" apkeditor.jar rsapksign rsapksign.tar.gz
fi

echo "Patched Minecraft apk has been generated in Download folder of Internal Storage."

exec > /dev/tty 2>&1 && mv $HOME/patch.log /storage/emulated/0/Download && exit
