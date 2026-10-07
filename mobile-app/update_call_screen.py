import re
import os

filepath = r"c:\Users\HP\Downloads\Aegismesh\Aegismesh\Aegismesh\mobile-app\lib\screens\calls\call_screen.dart"

with open(filepath, "r", encoding="utf-8") as f:
    code = f.read()

# Add new state variables
state_vars_new = """  double _threatScore = 0.0;
  double _syntheticProbability = 0.0;
  double _pitchVariance = 0.0;
  double _speakingRate = 0.0;
  double _semanticThreatProbability = 0.0;"""
code = code.replace("  double _threatScore = 0.0;", state_vars_new)

# Add onRiskStateUpdate handler
handshake_block = """      _sidecarService.onThreatScoreUpdate = (score) {
        if (mounted) setState(() => _threatScore = score);
      };"""
handshake_block_new = """      _sidecarService.onThreatScoreUpdate = (score) {
        if (mounted) setState(() => _threatScore = score);
      };
      _sidecarService.onRiskStateUpdate = (state) {
        if (mounted) {
          setState(() {
            _syntheticProbability = (state['synthetic_probability'] as num?)?.toDouble() ?? 0.0;
            _pitchVariance = (state['temporal_variance'] as num?)?.toDouble() ?? 0.0;
            _semanticThreatProbability = (state['semantic_threat_probability'] as num?)?.toDouble() ?? 0.0;
            _speakingRate = (state['speaking_rate'] as num?)?.toDouble() ?? 0.0;
          });
        }
      };"""
code = code.replace(handshake_block, handshake_block_new)

# Now, we need to completely replace the Expanded(child: Column(...)) part of the build method.
# We will use regex to find the Expanded section inside the Column of the Scaffold body.
# The body column starts around line 390.

replacement_ui = """
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Column(
                  children: [
                    // TOP HEADER
                    Text("CALLGUARD AI", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    Text("REAL-TIME CALL PROTECTION", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                    SizedBox(height: 24),
                    
                    // THREAT SCORE BIG CARD
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: _isIntercepted ? Colors.redAccent.withOpacity(0.1) : Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isIntercepted ? Colors.redAccent : _threatColor, width: 2),
                      ),
                      child: Column(
                        children: [
                          if (_isIntercepted)
                            Text("🚨 INTERCEPTION TRIGGERED", style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          if (_isIntercepted) SizedBox(height: 10),
                          
                          Text("${(_threatScore * 100).toStringAsFixed(0)} / 100", 
                            style: TextStyle(color: _isIntercepted ? Colors.redAccent : _threatColor, fontSize: 48, fontWeight: FontWeight.bold)),
                          Text("THREAT SCORE", style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 2)),
                          SizedBox(height: 8),
                          Text(_isIntercepted ? "CRITICAL RISK" : (_threatScore > 0.7 ? "ELEVATED RISK" : "MONITORING"), 
                            style: TextStyle(color: _isIntercepted ? Colors.redAccent : _threatColor, fontSize: 14, fontWeight: FontWeight.bold)),
                          SizedBox(height: 16),
                          Text("MULTI-MODAL RISK FUSION", style: TextStyle(color: Colors.grey[500], fontSize: 11, letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    Text("LIVE SECURITY ANALYSIS", style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    SizedBox(height: 16),
                    
                    // THREE CARDS ROW
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CARD 1: LIVENESS
                        Expanded(
                          child: _buildAnalysisCard(
                            title: "LIVENESS",
                            subtitle: "Voice Authenticity",
                            status: _threatScore == 0 ? "ANALYZING" : (_syntheticProbability > 0.7 ? "SYNTHETIC" : "HUMAN"),
                            isCritical: _syntheticProbability > 0.7,
                            details: [
                              "Human: ${((1.0 - _syntheticProbability)*100).toStringAsFixed(0)}%",
                              "Synthetic: ${(_syntheticProbability*100).toStringAsFixed(0)}%",
                            ]
                          ),
                        ),
                        SizedBox(width: 8),
                        // CARD 2: BEHAVIORAL
                        Expanded(
                          child: _buildAnalysisCard(
                            title: "BEHAVIORAL",
                            subtitle: "Acoustic + Temporal",
                            status: _threatScore == 0 ? "CALIBRATING" : (_speakingRate > 150 ? "SUSPICIOUS" : "NORMAL"),
                            isCritical: _speakingRate > 150,
                            details: [
                              "Pitch Var: ${_pitchVariance.toStringAsFixed(3)}",
                              "WPM: ${_speakingRate.toStringAsFixed(0)}",
                              _speakingRate > 150 ? "Stress: HIGH" : "Stress: LOW"
                            ]
                          ),
                        ),
                        SizedBox(width: 8),
                        // CARD 3: SEMANTIC
                        Expanded(
                          child: _buildAnalysisCard(
                            title: "SEMANTIC",
                            subtitle: "Conversation Intent",
                            status: _threatScore == 0 ? "ANALYZING" : (_semanticThreatProbability > 0.7 ? "HIGH RISK" : "LOW RISK"),
                            isCritical: _semanticThreatProbability > 0.7,
                            details: [
                              "Threat: ${(_semanticThreatProbability*100).toStringAsFixed(0)}%",
                              if (_semanticThreatProbability > 0.7) "⚠ Urgency",
                              if (_semanticThreatProbability > 0.7) "⚠ Extraction",
                            ]
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // TRANSCRIPT SECTION (If Intercepted)
                    if (_isIntercepted) ...[
                      Divider(color: Colors.grey[800]),
                      SizedBox(height: 8),
                      Text("AGENT HANDOFF ACTIVE", style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: _transcript.isEmpty
                            ? Center(child: Text('Waiting for Evelyn...', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _transcript.length,
                                itemBuilder: (ctx, i) {
                                  final item = _transcript[i];
                                  final isEvelyn = item['speaker'] == 'Evelyn';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: RichText(
                                      text: TextSpan(children: [
                                        TextSpan(
                                          text: '${item['speaker']}: ',
                                          style: TextStyle(
                                            color: isEvelyn ? Colors.greenAccent : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text: item['text'],
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
"""

import re
# We need to replace the entire Expanded block that contains the Avatar, Transcript, etc.
# From: Expanded( -> child: Column( -> mainAxisAlignment: MainAxisAlignment.center, ...
# To just before: // — Fail-safe manual text input for victim speech —

pattern = r"Expanded\(\s*child: Column\(\s*mainAxisAlignment: MainAxisAlignment\.center,[\s\S]*?(?=// — Fail-safe manual text input for victim speech —)"
code = re.sub(pattern, replacement_ui, code)

# Inject the _buildAnalysisCard helper method at the end of the class before `}`
helper_method = """
  Widget _buildAnalysisCard({required String title, required String subtitle, required String status, required bool isCritical, required List<String> details}) {
    Color statusColor = isCritical ? Colors.redAccent : (status.contains("ANALYZING") || status.contains("CALIBRATING") ? Colors.grey : Colors.greenAccent);
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 9)),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: statusColor),
              SizedBox(width: 4),
              Expanded(child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          SizedBox(height: 10),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Text(d, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          )),
        ],
      ),
    );
  }
}
"""
code = re.sub(r"}\s*class _ControlButton", helper_method + "\nclass _ControlButton", code)

with open(filepath, "w", encoding="utf-8") as f:
    f.write(code)
print("Updated successfully!")
