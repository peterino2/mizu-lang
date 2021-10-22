# Data Types 

This is where Mizu begins to really start differentiating itself from other
programmng languages. 

In that it provides some pretty powerful ideas for organization and
manipulation of collections of POD and Structs,

## Module 

Modules are named roughly after hardware description language modules,

Perhaps the easiest way to explain a module is to look at an example

```
module Entities 
{
    data {
        position: FVector2;
        size: FVector2;
        scale: FVector2;
        rotation: f32;
        velocity: FVector2;
        gravity_force: FVector2;
        force: FVector2;
        collision_box: Rect;

        name: string;
        health: f32;
        mana: f32;
        sprite: Sprite;

        _intermediate_bounds: Rect;
        _is_colliding: bool;
        _other_collders: ModuleIndex &[8];
    }

    struct _BroadPhaseCollisionSort { 
        min: f32;
        max: f32;
        id: ModuleIndex;
        proc sort_compare(self :Self) -> i32
        {
            return self.min;
        }
    }


    broad_phase_x_axis: Vector<_BroadPhaseCollisionSort>;
    potential_collisions: Vector<
        struct {
            a: _BroadPhaseCollisionSort, 
            b: _BroadPhaseCollisionSort,
        }>;

    flow update_transform {
        _intermediate_bounds = collision_box.rotate_at_center(rotation);
    }
    
    flow update_physics {

        param delta_time: f32;

        // velocity, force, gravity_force, position
        proc {
            velocity = velocity + (force + gravity_force) * delta_time;
            position = position + velocity * delta_time;
        }
    }

    dirty flow collision_broad_phase {
        init {
            broad_phase_x_axis.clear();
            potential_collisions.clear();
        }

        proc {

           broad_phase_x_axis.insert_sorted(
                _BroadPhaseCollisionSort{
                    min(
                        _intermediate_bounds[0].x,
                        _intermediate_bounds[1].x,
                        _intermediate_bounds[2].x,
                        _intermediate_bounds[3].x
                    ), 
                    max(
                        _intermediate_bounds[0].x,
                        _intermediate_bounds[1].x,
                        _intermediate_bounds[2].x,
                        _intermediate_bounds[3].x
                    ),
                },
                _BroadPhaseCollisionSort.sort_compare
            )
        }

        _is_colliding = false;
        _other_collders.clear();
        
        finish {
            broad_phase_x_axis.sort(_BroadPhaseCollisionSort.sort_compare);
            index: usize = 0;
            for object, id in broad_phase_x_axis.enumerate() {
                while(id < broad_phase_x_axis.length()){
                    id += 1;
                    if object.max >= broad_phase_x_axis[id].min {
                        potential_collisions.insert({object, broad_phase_x_axis[id]});
                    } else {
                        break;
                    }
                }
            }
        }
    }
    
    // Generate Collision events to the object if we really are colliding
    flow handle_collision_events(potential_collisions) {
        proc {
            let left = GetDataFromId(potential_collisions.a.id);
            let right = GetDataFromId(potential_collisions.b.id);

            if min(
                    left._intermediate_bounds[0].y,
                    left._intermediate_bounds[1].y,
                    left._intermediate_bounds[2].y,
                    left._intermediate_bounds[3].y
            ) > max ( 
                    right._intermediate_bounds[0].y,
                    right._intermediate_bounds[1].y,
                    right._intermediate_bounds[2].y,
                    right._intermediate_bounds[3].y
            ) or max(
                    left._intermediate_bounds[0].y,
                    left._intermediate_bounds[1].y,
                    left._intermediate_bounds[2].y,
                    left._intermediate_bounds[3].y
            ) < min ( 
                    right._intermediate_bounds[0].y,
                    right._intermediate_bounds[1].y,
                    right._intermediate_bounds[2].y,
                    right._intermediate_bounds[3].y
            ) {
                return;
            }

            // Check if any of lines intersect
            left_segments: Line[] = {
                Line{left._intermediate_bounds[0], left._intermediate_bounds[1]},
                Line{left._intermediate_bounds[1], left._intermediate_bounds[2]},
                Line{left._intermediate_bounds[2], left._intermediate_bounds[3]},
                Line{left._intermediate_bounds[3], left._intermediate_bounds[0]},
            };
            right_segments: Line[] = {
                Line{right._intermediate_bounds[0], right._intermediate_bounds[1]},
                Line{right._intermediate_bounds[1], right._intermediate_bounds[2]},
                Line{right._intermediate_bounds[2], right._intermediate_bounds[3]},
                Line{right._intermediate_bounds[3], right._intermediate_bounds[0]},
            };
            
            for l_segment in left_segments {
                for r_segment in right_segments{
                    if l_segment.intersects(r_segment) {
                        left._is_colliding = true;
                        left._other_collders.push(GetIdFromData(right));
                        right._is_colliding = true;
                        right._other_collders.push(GetIdFromData(left));
                    }
                }
            }
        }
    }
    
};
```
