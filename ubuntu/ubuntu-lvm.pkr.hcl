source "qemu" "lvm" {
  boot_command    = ["<wait>e<wait5>", "<down><wait><down><wait><down><wait2><end><wait5>", "<bs><bs><bs><bs><wait>autoinstall ---<wait><f10>"]
  boot_wait       = "2s"
  cpus            = 2
  disk_size       = "8G"
  format          = "raw"
  headless        = var.headless
  http_directory  = var.http_directory
  iso_checksum    = "sha256:10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
  iso_target_path = "packer_cache/ubuntu.iso"
  iso_url         = "https://old-releases.ubuntu.com/releases/22.04.1/ubuntu-22.04.1-live-server-amd64.iso"
  memory          = 2048
  qemuargs = [
    ["-vga", "qxl"],
    ["-device", "virtio-blk-pci,drive=drive0,bootindex=0"],
    ["-device", "virtio-blk-pci,drive=cdrom0,bootindex=1"],
    ["-device", "virtio-blk-pci,drive=drive1,bootindex=2"],
    ["-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd"],
    ["-drive", "if=pflash,format=raw,file=OVMF_VARS.fd"],
    ["-drive", "file=output-lvm/packer-lvm,if=none,id=drive0,cache=writeback,discard=ignore,format=raw"],
    ["-drive", "file=seeds-lvm.iso,format=raw,cache=none,if=none,id=drive1,readonly=on"],
    ["-drive", "file=packer_cache/ubuntu.iso,if=none,id=cdrom0,media=cdrom"]
  ]
  shutdown_command       = "sudo -S shutdown -P now"
  ssh_handshake_attempts = 500
  ssh_password           = var.ssh_ubuntu_password
  ssh_timeout            = "45m"
  ssh_username           = "ubuntu"
  ssh_wait_timeout       = "45m"
}

build {
  sources = ["source.qemu.lvm"]

  provisioner "file" {
    destination = "/tmp/curtin-hooks"
    source      = "${path.root}/scripts/curtin-hooks"
  }

  provisioner "shell" {
    environment_vars  = ["HOME_DIR=/home/ubuntu", "http_proxy=${var.http_proxy}", "https_proxy=${var.https_proxy}", "no_proxy=${var.no_proxy}"]
    execute_command   = "echo 'ubuntu' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    expect_disconnect = true
    scripts           = ["${path.root}/scripts/curtin.sh", "${path.root}/scripts/networking.sh", "${path.root}/scripts/cleanup.sh"]
  }

  post-processor "compress" {
    output = "custom-ubuntu-lvm.dd.gz"
  }
}
