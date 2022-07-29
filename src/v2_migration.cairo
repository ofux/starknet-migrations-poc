%lang starknet
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func a() -> (res : felt):
end

@storage_var
func b() -> (res : felt):
end

@storage_var
func ab() -> (res : felt):
end

@external
func migrate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (val_a) = a.read()
    let (val_b) = b.read()
    ab.write(val_a * val_b)
    return ()
end
