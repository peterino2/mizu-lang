
# Mizulang (Aka. mizu): a Dataflow Description Language

If you're not familiar with data oriented design I highly reccomend 
doing a bit of a deep dive into the topic yourself, especially if you think you'll
ever be doing anything performance critical.

Those familiar with DOD, are probably keenly aware of the patterns used.
'struct of arrays' is a wonderful construct that sadly has little official
support in any modern languages.

I've thought a ton about what kind of language constructs could be
theoretically added to say something like c++ that would make DOD design
patterns more easy to manage and to maintain, but the more usable and flexible
I make these kinds of constructs, the more it feels like I'm just describing
complex objects that have to then be manually compiled into designs.

So I just can't help but shake the feeling that the more I model helpers to 
'struct of arrays' on paper the more it looks like I'm describing a machine that 
transforms data rather than a set of procedures.

I have quite a bit of experience with HDL and verilog and so I figured that
some kind of descriptive, not procedural language might actually be the correct
answer here.

mizu is the name of this theoretical language. It is a dataflow paradigmn
language, (though I wonder how useful of moniker that is). It is intended to be
an auxillary systems level programming language.

At a high level, mizu libraries are described as a series of APIs that
construct and execute "dataflows". The language itself is closer to a
behavioral hardware description language such as SystemVerilog than a
tranditional programming language.

Programs describe contexts of data, and transformations that happen within each
context.  a 'synthesis' step will compile contexts and transformations into
modules of a target language and runtime. 

The basic mode of operation is to emit portable C99 code, and should be suitable 
for any kind of systems level task.

```{toctree}
podtypes_and_procs
data_types
```

# A rich and complete mizu object example

An example program written in mizu, this provides an API that performs a
transformation of object positions based on the current camera position, 
gets some debug information.

```{code-block} rust
cache_size: const isize = @'CacheSize();

api HelloMizu {

    struct Vector2 {
        x : i32;
        y : i32;
        proc @'op_sub(@'self, other: ref Vector2) -> Vector2
        {
            Vector2 {
                x: self.x - other.x,
                y: self.y - other.y,
            }
        }

        proc @'op_add(@'self, other: ref Vector2) -> Vector2
        {
            Vector2 {
                x: self.x + other.x,
                y: self.y + other.y,
            }
        }
    }

    struct Rect {
        position : Vector2,
        size : Vector2,
    }
    struct View Rect;

    module CanvasObjects
    {
        data
        {
            position: Vector2;                  // 8 bytes
            size: Vector2;                      // 8 bytes
            render_position: Vector2;           // 8 bytes
            render_bottom_left: Vector2;        // 8 bytes

            visible: bool@[0:0];                // 1 bit wide
            alive_time: i32@[0:15];             // 16 bit wide
            name: char[1024];                   // 8 bytes
        }
        
        // is allowed and procedure execution is allowed outside of debug
        flow render
        {
            param is_paused: bool;
            param view: ref View;
            param delta_time: f32;
            {
                // within a block, each step happens sequentially
                render_position = position - view.position;
                render_bottom_left = render_position + size;
            }
        }

        flow check_visible {
            // outside of a block, the code can be thought of as running in parallel
            visible = {
                if position.x > (view.position.x + view.size.x) or
                   position.y > (view.position.y + view.size.y) or
                   position.x + size.x < view.position.x or
                   position.y + size.y < view.position.y
                {
                    true
                }
                else {
                    false
                }
            }
        }

        // dirty flows and flows with priority = low
        // do not contribute to data packing hints and are naive
        dirty flow update
        {
            param debug_info: mut ref string;
            { 
                debug_info.append_chars();
            }
        }

        proc find_canvas_by_name(name: CharStr) -> mut ref CanvasObjects.data
        {
            for object in @'ContextData(canvas_object)
            {
                if object.name == name 
                {
                    return mut ref object;
                }
            }
        }
    }
}
```


# Example of output content, C API + zig implementation

```{code-block} c

HelloMizu.h

// _inner_data.h ------------------------
// c implementation inner
typedef struct {
    Vector2 position;
    Vector2 size;
    Vector2 render_position;
    Vector2 render_bottom_left;
} _MizuModule_CanvasObjectPackedStruct_01_t

typedef struct {
    _MizuModule_CanvasObjectPackedStruct_01_t* _packed_object_1;
    uint8_t* visible;                  // 1 byte 
    double* alive_time;                // 8 bytes
    char* name[1024];
} _MizuModule_CanvasObjectContext_t;


typedef struct {
    CanvasObjectContextHandle_t* ctx;
    uint32_t index;
} _innerCanvasObjectHandle_t;


// HelloMizu_datasets.h ------------------------

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t x;
    int32_t y;
} Vector2;

#ifdef __cplusplus
}
#endif

// HelloMizu.h ------------------------

#include <HelloMizu_datasets.h>

typedef struct CanvasObjectContextHandle_t;
typedef struct CanvasObjectHandle_t;

typedef struct {
    Vector2 position;
    Vector2 size;
    Vector2 render_position;
    Vector2 render_bottom_left;
    uint8_t visible;                  // 1 byte 
    double alive_time;                // 8 bytes
    char name[1024];
} CanvasObject_t;

typedef CanvasObjectConstructionParams_t CanvasObject_t;

CanvasObjectContextHandle_t* CreateModuleContext_CanvasObjects(size_t initial_size);

CanvasObject_CallFlow_Draw(CanvasObjectContextHandle_t* context);

Vector2 get_position(CanvasObjectHandle_t h);
{ 
    return h.ctx._packed_object_1.position;
} 

CanvasObjectHandle_t CanvasObject_Create(
    CanvasObjectContextHandle_t* context, 
    CanvasObjectConstructionParams_t ctor_params
);

```

```{code-block} zig
const std = @import("std");
const c = @cImport({
    @cInclude("HelloMizu.h");
})

const allocator = std.heap.c_allocator;

extern fn CreateModuleContext_CanvasObjects(initial_size: usize) ?*c.CanvasObjectContextHandle_t{
    var ret = allocator.create(CanvasObjectContext) catch return null;
    ret.* = CanvasObjectContext.initCapacity(usize) catch {
        allocator.free(ret);
        return null;
    }
    return @ptrCast(*c.CanvasObjectContextHandle_t, ret);
};

extern fn CanvasObject_CallFlow_Render(context: ?*c.CanvasObjectContextHandle_t, view: c.Vector2) {
    const ctx = CanvasObjectContextCast(context);
    for (ctx.items(._packed_object_1)) |*packed| {
        packed.render_position.x = packed.position.x - view.position.x;
        packed.render_position.y = packed.position.y - view.position.y;
        packed.render_bottom_left.x = packed.render_position.x + packed.size.x;
        packed.render_bottom_left.y = packed.render_position.y + packed.size.y;
    }
}

extern fn CanvasObject_CallFlow_Visible(context: ?*c.CanvasObjectContextHandle_t, view: c.Vector2) {
    const ctx = CanvasObjectContextCast(context);
    for (ctx.items(.visible)) |*visible, i| {
        const position = &ctx.items(._packed_object_1)[i].position;
        if (
            position.x > (view.position.x + view.size.x) or 
            position.y > (view.position.y + view.size.y) or
            position.x + size.x < view.position.x or
            position.y + size.y < view.position.y
        ) {
            visible.* = 0;
        } else {
            visible.* = 1;
        }
    }
}

const CanvasObjectContext = std.MultiArrayList(struct{
    _packed_object_1: struct {
        position: c.Vector2,
        size: c.Vector2,
        render_position: c.Vector2,
        render_bottom_left: c.Vector2, 
    },
    visible: u1,
    alive_time: f64,
    name: [1024]u8,
});

```

# High level sketch of standard library implementation

```{code-block} rust
    dataset char b8;

api cstr {
    
    dataset CharStr char[]
    {
        count = 0;
    }
    
    dataset CoherentCharStr CharStr
    '({
        packing_rule = packet'({ max_size = @'CacheLinesInSize(256) });
        align = @'CacheSize();
    })

    from std.chars.cstr use join;
    map insert_chars(source: mut ref CoherentCharStr, index: isize, other: CoherentCharStr)
    {
        i: mut isize = 0;
        for (i, v: char) in other[:other.count]
        {
            let j = i - index > 0 ? i - index : 0;
            source.index[j] = v;
        }
    }

    map append_chars(source: mut ref CoherentCharStr, other: CoherentCharStr)
    {
        insert_chars(source, source.count - 1, other);
    }

    map join_chars(source: mut ref CoherentCharStr, concats: *CoherentCharStr)
    {
        for(text in concats)
        {
            insert_chars(source, text);
        }
    }
    

    from std.chars.cstr use itoa32;
    map itoa32( value: i32, text: mut ref CharStr)
    {
        i: mut isize = 0;
        while(value > 0)
        {
            text[i] = value % 10;
            value = value / 10;
            i = i + 1;
        }
        text[i] = 0;
    }
}
```
