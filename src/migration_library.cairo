%lang starknet
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.upgrades.library import Proxy

@contract_interface
namespace IMigration:
    func migrate():
    end
end

@storage_var
func migrations_done(migration_hash : felt) -> (res : felt):
end

namespace migration:
    func execute{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        migration_hash : felt
    ):
        assert_execute_only_once(migration_hash)
        IMigration.library_call_migrate(migration_hash)
        return ()
    end

    func assert_execute_only_once{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(migration_hash : felt):
        let (res) = migrations_done.read(migration_hash)
        with_attr error_message("migration was already executed"):
            assert res = 0
        end
        migrations_done.write(migration_hash, 1)
        return ()
    end
end

namespace migrable_proxy:
    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        proxy_admin : felt
    ):
        Proxy.initializer(proxy_admin)
        return ()
    end

    func update_implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_implementation_hash : felt
    ):
        Proxy.assert_only_admin()
        Proxy._set_implementation_hash(new_implementation_hash)
        return ()
    end

    func update_implementation_with_migration{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(new_implementation_hash : felt, migration_hash : felt):
        Proxy.assert_only_admin()
        Proxy._set_implementation_hash(new_implementation_hash)
        migration.execute(migration_hash)
        return ()
    end

    func set_proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_admin : felt
    ):
        Proxy.assert_only_admin()
        Proxy._set_admin(new_admin)
        return ()
    end

    func get_implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (hash : felt):
        let (hash) = Proxy.get_implementation_hash()
        return (hash)
    end

    func get_proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        admin : felt
    ):
        let (admin) = Proxy.get_admin()
        return (admin)
    end
end
