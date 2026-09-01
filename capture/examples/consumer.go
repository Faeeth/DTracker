// Exemple de consommation des evenements depuis Go.
//
// La bibliotheque est lancee en sous-processus et ecrit une ligne JSON par
// evenement sur sa sortie standard. Aucun port n'est ouvert, rien n'est
// partage : le seul contrat est le format des lignes.
//
//	go run consumer.go
//
// Pour une interface web ou plusieurs consommateurs simultanes, lancer plutot
// la bibliotheque avec --mode websocket et s'abonner a ws://127.0.0.1:8765.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os/exec"
)

// Evenement ne declare que l'entete commun. Le champ Type indique quoi lire
// ensuite : chaque evenement se decode dans sa propre structure.
type Evenement struct {
	Type      string  `json:"type"`
	Timestamp float64 `json:"ts"`
	Source    string  `json:"source"`
}

type Participant struct {
	Nom    string `json:"name"`
	Niveau int    `json:"level"`
	Xp     int    `json:"xp"`
	Kamas  int    `json:"kamas"`
	Butin  []struct {
		ObjetID   int `json:"item_id"`
		Quantite  int `json:"quantity"`
		PrixUnite int `json:"unit_price"`
	} `json:"loot"`
}

type FinDeCombat struct {
	Evenement
	Participants []Participant `json:"participants"`
}

type Succes struct {
	Evenement
	Identifiant int `json:"achievement_id"`
	Xp          int `json:"xp"`
	Kamas       int `json:"kamas"`
}

func main() {
	cmd := exec.Command("python", "-m", "dofus_stats.cli.stream",
		"--read", "captures/challenge01.pcapng",
		"--hosts", "captures/hosts_challenge01.json")
	cmd.Dir = ".."

	sortie, err := cmd.StdoutPipe()
	if err != nil {
		panic(err)
	}
	if err := cmd.Start(); err != nil {
		panic(err)
	}

	scanner := bufio.NewScanner(sortie)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024) // certains evenements sont volumineux

	for scanner.Scan() {
		ligne := scanner.Bytes()

		var entete Evenement
		if err := json.Unmarshal(ligne, &entete); err != nil {
			continue
		}

		switch entete.Type {
		case "FightEnd":
			var e FinDeCombat
			if err := json.Unmarshal(ligne, &e); err != nil {
				continue
			}
			totalXp, totalKamas, valeurButin := 0, 0, 0
			for _, p := range e.Participants {
				totalXp += p.Xp
				totalKamas += p.Kamas
				for _, lot := range p.Butin {
					valeurButin += lot.PrixUnite * lot.Quantite
				}
			}
			fmt.Printf("combat termine : %d participants, %d xp, %d kamas, butin %d kamas\n",
				len(e.Participants), totalXp, totalKamas, valeurButin)

		case "AchievementUnlocked":
			var e Succes
			if err := json.Unmarshal(ligne, &e); err != nil {
				continue
			}
			fmt.Printf("succes %d : %d xp, %d kamas\n", e.Identifiant, e.Xp, e.Kamas)

		case "ChallengeResult":
			var e struct {
				Evenement
				Identifiant int  `json:"challenge_id"`
				Reussi      bool `json:"succeeded"`
			}
			if err := json.Unmarshal(ligne, &e); err != nil {
				continue
			}
			issue := "echoue"
			if e.Reussi {
				issue = "reussi"
			}
			fmt.Printf("challenge %d %s\n", e.Identifiant, issue)
		}
	}

	if err := cmd.Wait(); err != nil {
		panic(err)
	}
}
