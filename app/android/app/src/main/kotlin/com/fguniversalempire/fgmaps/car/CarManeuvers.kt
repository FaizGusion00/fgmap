package com.fguniversalempire.fgmaps.car

import androidx.car.app.navigation.model.Maneuver

/**
 * Memetakan nama `ManeuverKind` (Dart, `nav_route.dart`) kepada jenis manuver piawai Android Auto.
 * Lalu lintas Malaysia di sebelah kiri: bulatan ikut arah jam dan pusingan U ke kanan. Jenis yang
 * tiada padanan mengembalikan null, dan hos hanya memaparkan teks arahan.
 */
object CarManeuvers {
    fun build(kind: String?, roundaboutExit: Int?): Maneuver? {
        val type = when (kind) {
            "depart" -> Maneuver.TYPE_DEPART
            "straight", "keepStraight" -> Maneuver.TYPE_STRAIGHT
            "slightRight" -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
            "right" -> Maneuver.TYPE_TURN_NORMAL_RIGHT
            "sharpRight" -> Maneuver.TYPE_TURN_SHARP_RIGHT
            "slightLeft" -> Maneuver.TYPE_TURN_SLIGHT_LEFT
            "left" -> Maneuver.TYPE_TURN_NORMAL_LEFT
            "sharpLeft" -> Maneuver.TYPE_TURN_SHARP_LEFT
            "uTurn" -> Maneuver.TYPE_U_TURN_RIGHT
            "rampStraight" -> Maneuver.TYPE_STRAIGHT
            "rampRight", "exitRight" -> Maneuver.TYPE_OFF_RAMP_NORMAL_RIGHT
            "rampLeft", "exitLeft" -> Maneuver.TYPE_OFF_RAMP_NORMAL_LEFT
            "keepRight" -> Maneuver.TYPE_KEEP_RIGHT
            "keepLeft" -> Maneuver.TYPE_KEEP_LEFT
            "merge" -> Maneuver.TYPE_MERGE_SIDE_UNSPECIFIED
            "mergeRight" -> Maneuver.TYPE_MERGE_RIGHT
            "mergeLeft" -> Maneuver.TYPE_MERGE_LEFT
            "roundabout" ->
                if (roundaboutExit != null && roundaboutExit > 0) {
                    Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW
                } else {
                    Maneuver.TYPE_ROUNDABOUT_ENTER_CW
                }
            "ferry" -> Maneuver.TYPE_FERRY_BOAT
            "arrive" -> Maneuver.TYPE_DESTINATION
            "arriveRight" -> Maneuver.TYPE_DESTINATION_RIGHT
            "arriveLeft" -> Maneuver.TYPE_DESTINATION_LEFT
            else -> return null
        }
        val builder = Maneuver.Builder(type)
        if (type == Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW && roundaboutExit != null) {
            builder.setRoundaboutExitNumber(roundaboutExit)
        }
        return builder.build()
    }
}
