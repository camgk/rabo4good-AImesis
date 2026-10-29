// AG-UI/A2UI live agent integration — switch from REST mock when backend/agent is deployed.
//
// For the 29 Oct demo the care-team app talks to `backend/mock_api` over REST
// (see `AimesisApi` in package:aimesis_client). When `backend/agent` is live,
// this class will open an AG-UI run (HTTP + SSE) per patient, forward user
// actions (sign-off, confirm quoted note) as AG-UI events, and hand A2UI
// surface messages to [A2uiSurfaceHost].

/// Placeholder AG-UI session. Not used by the demo flow.
class AguiSession {
  AguiSession({required this.agentUrl, required this.patientId});

  final String agentUrl;
  final String patientId;

  bool get isLive => false;

  Future<void> start() async {}

  Future<void> close() async {}
}
