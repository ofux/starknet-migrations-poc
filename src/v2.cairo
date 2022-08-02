%lang starknet
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin
from migration_library import migrable_proxy

@storage_var
func ab() -> (res : felt):
end

@view
func get_ab{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = ab.read()
    ab.write(res + 1)
    return (res)
end

#
# Proxy / Upgrades
#
@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proxy_admin : felt
):
    migrable_proxy.initializer(proxy_admin)
    return ()
end

@view
func implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    hash : felt
):
    let (hash) = migrable_proxy.get_implementation()
    return (hash)
end

@view
func proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    admin : felt
):
    let (admin) = migrable_proxy.get_proxy_admin()
    return (admin)
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
