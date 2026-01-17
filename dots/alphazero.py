"""AlphaZero-style self-play loop for Dots and Boxes."""
from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from dots.engine import DotsAndBoxes, DotsAndBoxesState, normalize_policy


@dataclass
class TrainingExample:
    state: List[int]
    policy: List[float]
    value: float


class PolicyValueNet:
    def predict(self, state: DotsAndBoxesState) -> Tuple[List[float], float]:
        raise NotImplementedError


class UniformPolicyValueNet(PolicyValueNet):
    def __init__(self, action_size: int) -> None:
        self._action_size = action_size

    def predict(self, state: DotsAndBoxesState) -> Tuple[List[float], float]:
        legal = state.legal_actions()
        uniform = 1.0 / len(legal) if legal else 0.0
        priors = [uniform if idx in legal else 0.0 for idx in range(self._action_size)]
        return priors, 0.0


@dataclass
class MCTSConfig:
    num_simulations: int = 64
    c_puct: float = 1.25
    dirichlet_alpha: float = 0.3
    dirichlet_epsilon: float = 0.25


class MCTSNode:
    def __init__(self, to_play: int, prior: float, parent: Optional["MCTSNode"] = None) -> None:
        self.to_play = to_play
        self.prior = prior
        self.parent = parent
        self.children: Dict[int, MCTSNode] = {}
        self.visit_count = 0
        self.value_sum = 0.0

    def expanded(self) -> bool:
        return bool(self.children)

    def value(self) -> float:
        if self.visit_count == 0:
            return 0.0
        return self.value_sum / self.visit_count

    def select_child(self, c_puct: float) -> Tuple[int, "MCTSNode"]:
        total_visits = sum(child.visit_count for child in self.children.values())
        best_score = -float("inf")
        best_action = -1
        best_child = None
        for action, child in self.children.items():
            ucb = child.value() + c_puct * child.prior * math.sqrt(total_visits + 1) / (1 + child.visit_count)
            if ucb > best_score:
                best_score = ucb
                best_action = action
                best_child = child
        if best_child is None:
            raise RuntimeError("No child available for selection")
        return best_action, best_child

    def expand(self, priors: Sequence[float], legal_actions: Iterable[int], to_play: int) -> None:
        for action in legal_actions:
            self.children[action] = MCTSNode(to_play=to_play, prior=priors[action], parent=self)


class MCTS:
    def __init__(self, game: DotsAndBoxes, policy_value_net: PolicyValueNet, config: MCTSConfig) -> None:
        self.game = game
        self.policy_value_net = policy_value_net
        self.config = config

    def run(self, state: DotsAndBoxesState) -> MCTSNode:
        root = MCTSNode(to_play=state.current_player, prior=1.0)
        priors, _ = self.policy_value_net.predict(state)
        priors = normalize_policy(priors, state.legal_actions())
        priors = self._add_dirichlet_noise(priors, state.legal_actions())
        root.expand(priors, state.legal_actions(), state.current_player)

        for _ in range(self.config.num_simulations):
            node = root
            scratch_state = state.copy()
            search_path = [node]

            while node.expanded() and not scratch_state.is_terminal():
                action, node = node.select_child(self.config.c_puct)
                scratch_state = scratch_state.apply_action(action)
                search_path.append(node)

            if scratch_state.is_terminal():
                value = self._terminal_value(scratch_state, node.to_play)
            else:
                priors, value = self.policy_value_net.predict(scratch_state)
                priors = normalize_policy(priors, scratch_state.legal_actions())
                node.expand(priors, scratch_state.legal_actions(), scratch_state.current_player)

            self._backpropagate(search_path, value)

        return root

    def _terminal_value(self, state: DotsAndBoxesState, to_play: int) -> float:
        score_current, score_other = state.scores[to_play], state.scores[1 - to_play]
        if score_current > score_other:
            return 1.0
        if score_current < score_other:
            return -1.0
        return 0.0

    def _backpropagate(self, search_path: List[MCTSNode], value: float) -> None:
        for node in reversed(search_path):
            node.value_sum += value
            node.visit_count += 1
            if node.parent is not None and node.parent.to_play != node.to_play:
                value = -value

    def _add_dirichlet_noise(self, priors: Sequence[float], legal_actions: Sequence[int]) -> List[float]:
        if not legal_actions:
            return list(priors)
        alpha = self.config.dirichlet_alpha
        noise = [random.gammavariate(alpha, 1.0) for _ in legal_actions]
        total = sum(noise)
        noise = [n / total for n in noise]
        blended = list(priors)
        for idx, action in enumerate(legal_actions):
            blended[action] = (1 - self.config.dirichlet_epsilon) * priors[action] + self.config.dirichlet_epsilon * noise[idx]
        return blended


def select_action(policy: Sequence[float], legal_actions: Sequence[int], temperature: float) -> int:
    if not legal_actions:
        raise ValueError("No legal actions to select")
    if temperature <= 0:
        return max(legal_actions, key=lambda action: policy[action])
    weights = [policy[action] ** (1.0 / temperature) for action in legal_actions]
    total = sum(weights)
    if total <= 0:
        return random.choice(list(legal_actions))
    threshold = random.random() * total
    cumulative = 0.0
    for action, weight in zip(legal_actions, weights):
        cumulative += weight
        if cumulative >= threshold:
            return action
    return legal_actions[-1]


def self_play(
    game: DotsAndBoxes,
    policy_value_net: PolicyValueNet,
    config: MCTSConfig,
    num_games: int = 1,
    temperature: float = 1.0,
) -> List[TrainingExample]:
    examples: List[TrainingExample] = []
    for _ in range(num_games):
        state = game.initial_state()
        trajectory: List[Tuple[List[int], List[float], int]] = []
        while not state.is_terminal():
            mcts = MCTS(game, policy_value_net, config)
            root = mcts.run(state)
            visit_counts = [0] * game.action_size
            for action, child in root.children.items():
                visit_counts[action] = child.visit_count
            total_visits = sum(visit_counts)
            if total_visits == 0:
                policy = normalize_policy([1.0] * game.action_size, state.legal_actions())
            else:
                policy = [count / total_visits for count in visit_counts]
            trajectory.append((state.serialize(), policy, state.current_player))
            action = select_action(policy, state.legal_actions(), temperature)
            state = state.apply_action(action)
        final_scores = state.outcome()
        for serialized_state, policy, to_play in trajectory:
            score_diff = final_scores[to_play] - final_scores[1 - to_play]
            if score_diff > 0:
                value = 1.0
            elif score_diff < 0:
                value = -1.0
            else:
                value = 0.0
            examples.append(TrainingExample(serialized_state, policy, value))
    return examples
