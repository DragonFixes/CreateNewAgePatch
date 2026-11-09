> **Note:** This file was written specifically for Claude (Claude Code), so
> some wording may not fit other agents exactly — e.g. Claude-specific tool
> names, skills, or features. Interpret those in terms of your own equivalents.
>
> The master copy of the global rules these instructions build on lives at
> `{USER HOME}/.claude/CLAUDE.md` (e.g. `C:\Users\<user>\.claude\CLAUDE.md`).
> Read it as well; rules there apply unless this file overrides them.

# CreateNewAgePatch

Forge 1.20.1 (47.x) mod, server-side only, mod id `createnewagepatch`. It fixes
the datapack-load crash

```
java.lang.IncompatibleClassChangeError: Method 'int net.minecraft.world.item.ItemStack.getEnchantmentLevel(net.minecraft.world.item.enchantment.Enchantment)' must be Methodref constant
```

that happens when **Create: New Age 1.1.7+** (which bundles the ESL library)
and **ElementalCraft** are installed together. It modifies no other mod's jar;
it repairs the bytecode while `ItemStack` is being transformed.

## Cause

- ElementalCraft's `MixinItemStack` overrides `getEnchantmentLevel` and
  `getAllEnchantments` and calls `IForgeItemStack.super.<method>()`
  (`invokespecial`, interface flag set).
- ESL's `CapabilityProviderMixin` makes `CapabilityProvider`, the superclass of
  `ItemStack`, a mixin target.
- When a target's hierarchy contains another mixin target, Mixin 0.8.x's
  `MixinTargetContext.transformMethodRef` → `updateStaticBinding` rebinds
  `invokespecial` calls to the hierarchy's implementor. It sets the owner to
  `ItemStack` but keeps the interface flag, producing an invalid
  InterfaceMethodref, `ItemStack.getEnchantmentLevel`.
- Create: New Age 1.1.4 has no ESL, which is why downgrading also avoids it.

## How the fix works

- `mixin/ItemStackMarkerMixin` is an empty mixin on `ItemStack`, listed
  under `"server"` in `createnewagepatch.mixins.json`, so it only applies on
  dedicated servers.
- `plugin/SuperCallFixPlugin.postApply` runs after **all** mixins are merged
  into `ItemStack`. It finds `invokespecial` calls whose owner is the target
  class but which are flagged as interface calls, and points them back to the
  direct superinterface that declares the default method.
- `mods.toml` uses `displayTest="IGNORE_SERVER_VERSION"`, so clients can join
  without the mod.

## Building

No Gradle. `build.ps1` compiles with `javac --release 17` against jars from a
1.20.1 Forge/Mohist server's `libraries` folder: javafmllanguage, fmlcore,
mixin, asm, asm-tree and log4j-api. The output is
`build\createnewagepatch-<version>.jar`. The version comes from `version.txt`.

```powershell
.\build.ps1
.\build.ps1 -CopyTo "$env:USERPROFILE\curseforge\minecraft\Instances\Com (SRV) (T)\mods"
.\build.ps1 -LibrariesDir D:\servers\pack\libraries -Version 1.0.1
build.bat -CopyTo "%USERPROFILE%\curseforge\minecraft\Instances\Com (SRV) (T)\mods"
```

`-LibrariesDir` defaults to the Com (SRV) (T) test server's `libraries`.

## Verifying

Boot the server with Create: New Age 1.2.0 and ElementalCraft installed. The
log should show `[CreateNewAgePatch] Rebinding net/minecraft/world/item/ItemStack.getEnchantmentLevel...`
and the server should reach `Done (`, with no `must be Methodref constant`.
