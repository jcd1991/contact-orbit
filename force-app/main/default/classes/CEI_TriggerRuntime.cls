/**
 * Small, package-owned trigger runtime guard.
 *
 * The guard is deliberately internal: subscribers can extend Contact Orbit
 * through metadata and global service contracts, but cannot reorder or bypass
 * the package's trust-sensitive trigger actions with arbitrary class names.
 */
public without sharing class CEI_TriggerRuntime {
    @TestVisible
    private static Set<String> activeKeys = new Set<String>();

    public static Boolean enter(String actionKey) {
        if (String.isBlank(actionKey) || activeKeys.contains(actionKey)) return false;
        activeKeys.add(actionKey);
        return true;
    }

    public static void exit(String actionKey) {
        if (!String.isBlank(actionKey)) activeKeys.remove(actionKey);
    }
}
