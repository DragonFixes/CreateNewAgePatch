package gg.drak.createnewagepatch.plugin;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.AbstractInsnNode;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;
import org.spongepowered.asm.mixin.extensibility.IMixinConfigPlugin;
import org.spongepowered.asm.mixin.extensibility.IMixinInfo;
import org.spongepowered.asm.mixin.transformer.ClassInfo;

import java.util.List;
import java.util.Set;

/**
 * Repairs interface super calls that Mixin 0.8.x rebinds incorrectly.
 *
 * <p>A mixin can call an interface default method with
 * {@code IFoo.super.bar()}, which compiles to
 * {@code invokespecial IFoo.bar} with the interface flag set. When any class
 * above the target in its hierarchy is itself a mixin target, Mixin's
 * {@code MixinTargetContext.updateStaticBinding} moves that call's owner to
 * the target class and leaves the interface flag set. The result,
 * {@code invokespecial Target.bar} as an InterfaceMethodref, fails with
 * {@code IncompatibleClassChangeError: ... must be Methodref constant} the
 * first time it runs.
 *
 * <p>In practice: ElementalCraft's {@code MixinItemStack} calls
 * {@code IForgeItemStack.super.getEnchantmentLevel} and
 * {@code getAllEnchantments}, and ESL (bundled in Create: New Age 1.1.7 and
 * later) mixes into {@code CapabilityProvider}, the superclass of
 * {@code ItemStack}. Together they break every enchantment lookup and abort
 * datapack loading.
 *
 * <p>{@link #postApply} runs after all mixins are merged into the target. Any
 * {@code invokespecial} whose owner is the target class itself but which is
 * flagged as an interface call is pointed back at the direct superinterface
 * that declares the default method, which restores the call the mixin's
 * source asked for.
 */
public final class SuperCallFixPlugin implements IMixinConfigPlugin {
    private static final Logger LOGGER = LogManager.getLogger("CreateNewAgePatch");

    @Override
    public void onLoad(String mixinPackage) {
    }

    @Override
    public String getRefMapperConfig() {
        return null;
    }

    @Override
    public boolean shouldApplyMixin(String targetClassName, String mixinClassName) {
        return true;
    }

    @Override
    public void acceptTargets(Set<String> myTargets, Set<String> otherTargets) {
    }

    @Override
    public List<String> getMixins() {
        return null;
    }

    @Override
    public void preApply(String targetClassName, ClassNode targetClass, String mixinClassName, IMixinInfo mixinInfo) {
    }

    @Override
    public void postApply(String targetClassName, ClassNode targetClass, String mixinClassName, IMixinInfo mixinInfo) {
        int fixed = 0;
        for (MethodNode method : targetClass.methods) {
            if (method.instructions == null) continue;
            for (AbstractInsnNode insn : method.instructions) {
                if (!(insn instanceof MethodInsnNode call)) continue;
                if (call.getOpcode() != Opcodes.INVOKESPECIAL || !call.itf) continue;
                if (!call.owner.equals(targetClass.name)) continue;

                String iface = findDefaultDeclarer(targetClass, call.name, call.desc);
                if (iface == null) {
                    LOGGER.warn("Found invalid interface super call {}.{}{} in {}.{} but no direct superinterface declares it; leaving it alone",
                            call.owner, call.name, call.desc, targetClass.name, method.name);
                    continue;
                }
                LOGGER.info("Rebinding {}.{}{} in {}.{} to {}",
                        call.owner, call.name, call.desc, targetClass.name, method.name, iface);
                call.owner = iface;
                fixed++;
            }
        }
        if (fixed > 0) {
            LOGGER.info("Repaired {} interface super call(s) in {}", fixed, targetClassName);
        }
    }

    /**
     * Returns the direct superinterface of {@code target} that declares a
     * non-abstract (default) method {@code name desc}, or {@code null}.
     * {@code invokespecial} on an interface is only legal against a direct
     * superinterface, so inherited interfaces are not searched.
     */
    private static String findDefaultDeclarer(ClassNode target, String name, String desc) {
        if (target.interfaces == null) return null;
        for (String iface : target.interfaces) {
            ClassInfo info = ClassInfo.forName(iface);
            if (info == null) continue;
            ClassInfo.Method m = info.findMethod(name, desc, ClassInfo.INCLUDE_ALL);
            if (m != null && !m.isAbstract()) return iface;
        }
        return null;
    }
}
