# poison

When we enable CONFIG_PAGE_POISONING, the pages are filled with poison byte pattern after free_pages() and verifying the poison patterns before alloc_pages(). [^1]

如果 Guest 打开了 poison，但是又打开了 virtio-balloon，那么问题就来了，

[^1]: https://stackoverflow.com/questions/22717661/linux-page-poisoning
