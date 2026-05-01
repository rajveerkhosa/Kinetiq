from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple


@dataclass
class UserCluster:
    centroid: List[float]
    count: int = 0


@dataclass
class UserClustering:
    """
    Online k-means (k=3) clustering of users by training style.

    Feature vector (4 dims):
        [avg_rpe/10, weight_prog_rate, session_freq/7, exercise_diversity]

    Cluster priors:
        0 = strength-focused  (low RPE, high weight progression, low freq, low variety)
        1 = hypertrophy-focused (high RPE, low weight progression, high freq, high variety)
        2 = mixed

    When a new user has < 5 sessions, their embedding is initialized from the
    nearest cluster centroid via initialize_new_user_embedding().
    """

    k: int = 3
    feature_dim: int = 4
    session_update_interval: int = 10

    clusters: Dict[int, UserCluster] = field(default_factory=dict)
    user_assignments: Dict[str, Tuple[int, int]] = field(default_factory=dict)
    user_session_counts: Dict[str, int] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.clusters:
            self._init_clusters()

    def _init_clusters(self) -> None:
        self.clusters = {
            0: UserCluster(centroid=[0.72, 0.40, 0.43, 0.20]),  # strength
            1: UserCluster(centroid=[0.88, 0.05, 0.79, 0.80]),  # hypertrophy
            2: UserCluster(centroid=[0.80, 0.20, 0.57, 0.50]),  # mixed
        }

    def _euclidean(self, a: List[float], b: List[float]) -> float:
        return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))

    def _nearest_cluster(self, features: List[float]) -> int:
        best_id = 0
        best_dist = float("inf")
        for cid, cluster in self.clusters.items():
            d = self._euclidean(features, cluster.centroid)
            if d < best_dist:
                best_dist, best_id = d, cid
        return best_id

    def assign_cluster(self, user_id: str, features: List[float]) -> int:
        """
        Assign user to nearest cluster, update centroid with running mean.
        Re-assigns every session_update_interval sessions.
        Returns cluster_id.
        """
        session_count = self.user_session_counts.get(user_id, 0) + 1
        self.user_session_counts[user_id] = session_count

        prev_assignment = self.user_assignments.get(user_id)

        # Re-assign on first call or every session_update_interval sessions
        if prev_assignment is None or session_count % self.session_update_interval == 0:
            cluster_id = self._nearest_cluster(features)
        else:
            cluster_id = prev_assignment[0]

        # Running mean update for the assigned cluster
        cluster = self.clusters[cluster_id]
        cluster.count += 1
        for i in range(self.feature_dim):
            cluster.centroid[i] += (features[i] - cluster.centroid[i]) / cluster.count

        self.user_assignments[user_id] = (cluster_id, session_count)
        return cluster_id

    def get_cluster_centroid(self, cluster_id: int) -> List[float]:
        return self.clusters[cluster_id].centroid[:]

    def initialize_new_user_embedding(
        self,
        user_id: str,
        session_count: int,
        features: List[float],
        embedding_table,
    ) -> None:
        """
        If user has < 5 sessions, seed their embedding from the nearest cluster centroid.
        Both the clustering feature vector and embedding are 4-dim by design.
        """
        if session_count >= 5:
            return
        cluster_id = self._nearest_cluster(features)
        centroid = self.get_cluster_centroid(cluster_id)
        # Write centroid values directly into the embedding table
        if user_id not in embedding_table.table:
            embedding_table.table[user_id] = centroid[: embedding_table.dim]

    def to_dict(self) -> dict:
        return {
            "k": self.k,
            "feature_dim": self.feature_dim,
            "session_update_interval": self.session_update_interval,
            "clusters": {
                str(cid): {"centroid": c.centroid, "count": c.count}
                for cid, c in self.clusters.items()
            },
            "user_assignments": {
                uid: list(v) for uid, v in self.user_assignments.items()
            },
            "user_session_counts": self.user_session_counts,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "UserClustering":
        obj = cls(
            k=d["k"],
            feature_dim=d["feature_dim"],
            session_update_interval=d["session_update_interval"],
        )
        obj.clusters = {
            int(cid): UserCluster(centroid=v["centroid"], count=v["count"])
            for cid, v in d["clusters"].items()
        }
        obj.user_assignments = {
            uid: tuple(v) for uid, v in d["user_assignments"].items()
        }
        obj.user_session_counts = d["user_session_counts"]
        return obj
