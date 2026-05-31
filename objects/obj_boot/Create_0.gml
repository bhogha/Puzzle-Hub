// Boot: create persistent manager then jump to hub
if (!instance_exists(obj_persistent)) {
    instance_create_depth(0, 0, 0, obj_persistent);
}
room_goto(rm_hub);
