package gg.drak.createnewagepatch.mixin;

import org.spongepowered.asm.mixin.Mixin;

/**
 * Empty mixin. It adds nothing to {@code ItemStack}; it exists so that Mixin
 * calls {@link gg.drak.createnewagepatch.plugin.SuperCallFixPlugin#postApply} with
 * the finished {@code ItemStack} class after every other mod's mixins have
 * been merged into it.
 */
@Mixin(targets = "net.minecraft.world.item.ItemStack")
public abstract class ItemStackMarkerMixin {
}
