// AG-UI/A2UI live agent integration — switch from REST mock when backend/agent is deployed.
//
// Will render A2UI surfaces streamed by the agent using ONLY the components in
// package:aimesis_a2ui_catalog. Today the workspace pages render the same
// catalog widgets (TierBadge, DexStatusBanner, AdvisoryBanner) from REST data.

import 'package:flutter/material.dart';

/// Placeholder host for agent-driven A2UI surfaces.
class A2uiSurfaceHost extends StatelessWidget {
  const A2uiSurfaceHost({super.key, this.surfaceId});

  final String? surfaceId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
