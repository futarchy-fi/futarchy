"""Dots and Boxes game engine supporting arbitrary board sizes."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List, Sequence, Tuple


@dataclass(frozen=True)
class DotsAndBoxesConfig:
    rows: int
    cols: int

    @property
    def num_boxes(self) -> int:
        return self.rows * self.cols

    @property
    def num_horizontal_edges(self) -> int:
        return (self.rows + 1) * self.cols

    @property
    def num_vertical_edges(self) -> int:
        return self.rows * (self.cols + 1)

    @property
    def num_edges(self) -> int:
        return self.num_horizontal_edges + self.num_vertical_edges


@dataclass
class DotsAndBoxesState:
    config: DotsAndBoxesConfig
    horizontal_edges: List[bool]
    vertical_edges: List[bool]
    box_owners: List[int]
    current_player: int
    scores: List[int]

    @classmethod
    def new(cls, rows: int, cols: int) -> "DotsAndBoxesState":
        config = DotsAndBoxesConfig(rows=rows, cols=cols)
        return cls(
            config=config,
            horizontal_edges=[False] * config.num_horizontal_edges,
            vertical_edges=[False] * config.num_vertical_edges,
            box_owners=[-1] * config.num_boxes,
            current_player=0,
            scores=[0, 0],
        )

    def copy(self) -> "DotsAndBoxesState":
        return DotsAndBoxesState(
            config=self.config,
            horizontal_edges=self.horizontal_edges.copy(),
            vertical_edges=self.vertical_edges.copy(),
            box_owners=self.box_owners.copy(),
            current_player=self.current_player,
            scores=self.scores.copy(),
        )

    def is_terminal(self) -> bool:
        return all(self.horizontal_edges) and all(self.vertical_edges)

    def legal_actions(self) -> List[int]:
        actions = []
        for idx, taken in enumerate(self.horizontal_edges):
            if not taken:
                actions.append(idx)
        offset = self.config.num_horizontal_edges
        for idx, taken in enumerate(self.vertical_edges):
            if not taken:
                actions.append(offset + idx)
        return actions

    def apply_action(self, action: int) -> "DotsAndBoxesState":
        if action < 0 or action >= self.config.num_edges:
            raise ValueError(f"Action {action} out of range")
        state = self.copy()
        completed_boxes = 0
        if action < state.config.num_horizontal_edges:
            if state.horizontal_edges[action]:
                raise ValueError(f"Horizontal edge {action} already taken")
            state.horizontal_edges[action] = True
            completed_boxes += state._update_boxes_for_horizontal(action)
        else:
            vertical_index = action - state.config.num_horizontal_edges
            if state.vertical_edges[vertical_index]:
                raise ValueError(f"Vertical edge {vertical_index} already taken")
            state.vertical_edges[vertical_index] = True
            completed_boxes += state._update_boxes_for_vertical(vertical_index)

        if completed_boxes:
            state.scores[state.current_player] += completed_boxes
        else:
            state.current_player = 1 - state.current_player
        return state

    def outcome(self) -> Tuple[int, int]:
        return tuple(self.scores)  # type: ignore[return-value]

    def serialize(self) -> List[int]:
        return [
            int(value) for value in self.horizontal_edges
        ] + [int(value) for value in self.vertical_edges] + [
            self.current_player
        ]

    def _update_boxes_for_horizontal(self, edge_index: int) -> int:
        completed = 0
        row = edge_index // self.config.cols
        col = edge_index % self.config.cols
        if row > 0:
            completed += self._claim_box(row - 1, col)
        if row < self.config.rows:
            completed += self._claim_box(row, col)
        return completed

    def _update_boxes_for_vertical(self, edge_index: int) -> int:
        completed = 0
        row = edge_index // (self.config.cols + 1)
        col = edge_index % (self.config.cols + 1)
        if col > 0:
            completed += self._claim_box(row, col - 1)
        if col < self.config.cols:
            completed += self._claim_box(row, col)
        return completed

    def _claim_box(self, row: int, col: int) -> int:
        if row < 0 or row >= self.config.rows or col < 0 or col >= self.config.cols:
            return 0
        box_index = row * self.config.cols + col
        if self.box_owners[box_index] != -1:
            return 0
        top = row * self.config.cols + col
        bottom = (row + 1) * self.config.cols + col
        left = row * (self.config.cols + 1) + col
        right = row * (self.config.cols + 1) + (col + 1)
        if (
            self.horizontal_edges[top]
            and self.horizontal_edges[bottom]
            and self.vertical_edges[left]
            and self.vertical_edges[right]
        ):
            self.box_owners[box_index] = self.current_player
            return 1
        return 0


class DotsAndBoxes:
    def __init__(self, rows: int, cols: int) -> None:
        self.config = DotsAndBoxesConfig(rows=rows, cols=cols)

    @property
    def action_size(self) -> int:
        return self.config.num_edges

    def initial_state(self) -> DotsAndBoxesState:
        return DotsAndBoxesState.new(self.config.rows, self.config.cols)

    def action_to_edge(self, action: int) -> Tuple[str, int]:
        if action < 0 or action >= self.config.num_edges:
            raise ValueError(f"Action {action} out of range")
        if action < self.config.num_horizontal_edges:
            return ("horizontal", action)
        return ("vertical", action - self.config.num_horizontal_edges)

    def edge_to_action(self, edge_type: str, index: int) -> int:
        if edge_type == "horizontal":
            if index < 0 or index >= self.config.num_horizontal_edges:
                raise ValueError("Horizontal edge index out of range")
            return index
        if edge_type == "vertical":
            if index < 0 or index >= self.config.num_vertical_edges:
                raise ValueError("Vertical edge index out of range")
            return self.config.num_horizontal_edges + index
        raise ValueError("edge_type must be 'horizontal' or 'vertical'")

    def render_edges(self, state: DotsAndBoxesState) -> List[str]:
        rows = []
        for r in range(self.config.rows + 1):
            row_bits = []
            for c in range(self.config.cols):
                idx = r * self.config.cols + c
                row_bits.append("---" if state.horizontal_edges[idx] else "   ")
            rows.append("+" + "+".join(row_bits) + "+")
            if r < self.config.rows:
                col_bits = []
                for c in range(self.config.cols + 1):
                    idx = r * (self.config.cols + 1) + c
                    col_bits.append("|" if state.vertical_edges[idx] else " ")
                rows.append(" ".join(col_bits))
        return rows


def legal_action_mask(action_size: int, legal_actions: Iterable[int]) -> List[int]:
    mask = [0] * action_size
    for action in legal_actions:
        mask[action] = 1
    return mask


def normalize_policy(priors: Sequence[float], legal_actions: Iterable[int]) -> List[float]:
    legal_set = set(legal_actions)
    filtered = [p if idx in legal_set else 0.0 for idx, p in enumerate(priors)]
    total = sum(filtered)
    if total <= 0:
        uniform = 1.0 / len(legal_set) if legal_set else 0.0
        return [uniform if idx in legal_set else 0.0 for idx in range(len(priors))]
    return [p / total for p in filtered]
