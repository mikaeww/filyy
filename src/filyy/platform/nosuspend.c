// Preloaded into Filyy only: advertises xdg_wm_base as version 5, so Qt never binds v6 and the
// compositor never sends xdg_toplevel.suspended. Hyprland 0.56 sets suspended on visible, active
// windows after some drags; Qt then stops rendering and the old frame gets stretched.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client-core.h>

struct registry_listener {
    void (*global)(void *, void *, uint32_t, const char *, uint32_t);
    void (*global_remove)(void *, void *, uint32_t);
};

struct hooked {
    struct registry_listener wrapper;
    const struct registry_listener *original;
};

// libwayland hands the listener pointer back as the first slot, so the wrapper sits at offset 0
// and each handler finds its original through the proxy.
static const struct registry_listener *original_for(void *registry) {
    return ((const struct hooked *)wl_proxy_get_listener(registry))->original;
}

static void on_global(void *data, void *registry, uint32_t name, const char *interface, uint32_t version) {
    if (strcmp(interface, "xdg_wm_base") == 0 && version > 5)
        version = 5;
    original_for(registry)->global(data, registry, name, interface, version);
}

static void on_global_remove(void *data, void *registry, uint32_t name) {
    original_for(registry)->global_remove(data, registry, name);
}

int wl_proxy_add_listener(struct wl_proxy *proxy, void (**implementation)(void), void *data) {
    static int (*next)(struct wl_proxy *, void (**)(void), void *);
    if (!next)
        next = dlsym(RTLD_NEXT, "wl_proxy_add_listener");
    if (strcmp(wl_proxy_get_class(proxy), "wl_registry") != 0)
        return next(proxy, implementation, data);
    // ponytail: one small allocation per registry, never freed; Qt creates a handful per process.
    struct hooked *hook = malloc(sizeof *hook);
    if (!hook)
        return next(proxy, implementation, data);
    hook->wrapper = (struct registry_listener){ on_global, on_global_remove };
    hook->original = (const struct registry_listener *)implementation;
    return next(proxy, (void (**)(void))&hook->wrapper, data);
}
