<h1>ISO USB Boot Maker</h1>

<h2>Table of Contents</h2>

- [Introduction](#introduction)
- [Usage](#usage)
- [Options](#options)
- [Steps](#steps)
- [Prerequisites](#prerequisites)
- [Error Handling](#error-handling)
- [Important Notes](#important-notes)
- [License](#license)
- [Contributing](#contributing)

---

## Introduction

This script provides a safe and user-friendly way to create bootable USB drives from ISO files. It includes features like ISO downloading, disk validation, and safe unmounting procedures.

## Usage

You can simply clone the directory and run the script:

```bash
git clone https://github.com/Mik-TF/isobootmaker
cd isobootmaker
bash isoboot.sh
```

## Options

* `bash isoboot.sh help`: Display the help message with usage instructions.

## Steps

1. **Unmount (Optional):** Prompts to unmount any existing mount points.
2. **Disk Selection:** Prompts for the target disk (e.g., `/dev/sdb`). **Must be a valid device.**
3. **ISO Source:** Accepts either:
   - Local ISO file path
   - URL to download ISO file
4. **Validation:** Verifies the ISO file exists and has the correct extension.
5. **Disk Layout:** Displays current disk configuration using `lsblk`.
6. **Confirmation:** Requires explicit confirmation before formatting.
7. **Writing:** Writes the ISO to the USB drive using `dd`.
8. **Ejection:** Optionally ejects the USB drive when complete.

## Prerequisites

The script requires the following tools:
* `dd`: For writing the ISO to USB
* `rsync`: For file operations
* `mount`: For mounting operations
* `wget`: For downloading ISOs
* `sudo`: Administrative privileges for disk operations

## Error Handling

The script includes comprehensive error handling for:
* Invalid disk selection
* Missing dependencies
* ISO download failures
* ISO validation issues
* Writing errors
* Mount/unmount problems

## Important Notes

* **⚠️ DATA LOSS WARNING:** This script will completely erase the target disk. Double-check your disk selection!
* **System Protection:** The script prevents formatting of `/dev/sda` to protect system disks.
* **Mounted Disks:** The script checks for and prevents operations on mounted disks.
* **Interactive Design:** Provides exit options at every step for safety.

## License

This work is under [Apache 2.0 license](./LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit pull requests with improvements or bug fixes.
