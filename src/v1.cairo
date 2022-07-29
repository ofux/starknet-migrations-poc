%lang starknet
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func a() -> (res : felt):
end

@storage_var
func b() -> (res : felt):
end

@view
func get_ab{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (val_a) = a.read()
    let (val_b) = b.read()
    return (val_a * val_b)
end

#
# Proxy / Upgrades
#

@view
func implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address : felt
):
    return migrable_proxy.get_implementation()
end

@view
func proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    admin : felt
):
    return migrable_proxy.get_proxy_admin()
end

@external
func update_implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation_hash : felt
):
    migrable_proxy.update_implementation(new_implementation_hash)
    return ()
end

@external
func update_implementation_with_migration{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(new_implementation_hash : felt, migration_hash : felt):
    migrable_proxy.update_implementation_with_migration(new_implementation_hash, migration_hash)
    return ()
end

@external
func set_proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_admin : felt
):
    migrable_proxy.set_proxy_admin(new_admin)
    return ()
end