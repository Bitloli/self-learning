## avic
- [ ] https://lwn.net/Articles/680619/
- [ ] https://lwn.net/Articles/895708/

## nested

## svm

- `kvm_x86_init_ops` 提供对于 vmcs 的标准访问，和 `kvm_x86_ops` 的关系
  - 后者是: `runtime_ops`

- `kvm_init`
  - `kvm_arch_hardware_setup`
    - `kvm_ops_update`: 更新 `runtime_ops`
  - `kvm_async_pf_init`
