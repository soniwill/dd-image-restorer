# dd-image-restorer

In my work, I often need to restore operating system images to SSDs from .img files. The traditional process of removing the SSD from the PC, connecting it to a USB case, and performing the procedure with dd on another machine is tedious and inefficient.

To streamline this workflow and challenge myself technically, I developed a Docker container that acts as a PXE boot server (ProxyDHCP) and a web service for uploading .img files. With this solution, you only need to configure the target machine to boot via network, upload the .img file, and proceed with the restoration process without removing the SSD from the target PC.

This project aims to simplify and automate image restoration in a practical and efficient way, particularly useful in testing or development environments.
