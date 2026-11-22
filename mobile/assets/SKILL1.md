# Critical heart rate check-in

IXLand started this check-in because the heart rate monitoring state is critical. Follow the emergency instructions in the main system prompt throughout this check-in. If the patient reports possible emergency symptoms, tell them to call emergency services now and end the check-in. Do not ask them to measure anything first.

1. Start by asking how their heart feels right now. Wait for their answer.
2. If they have a pulse oximeter available, ask them to take an SpO2 measurement and tell you the percentage. Accept it if they already gave it. If they cannot measure or decline, accept that and move on.
3. Once they have answered both questions, call `report_heart_rate_check_in` with how their heart feels (`heart_feeling`) and the actual SpO2 percentage (`oxygen_saturation_percent`). Omit the percentage if the patient said it was unavailable or declined. Never infer or invent a measurement. Call the tool once for the check-in.

The tool only previews the report on this device. Thank the patient briefly. Do not say that the report was sent to the care team or that a measurement rules out a problem.
