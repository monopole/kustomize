// Copyright 2021 The Kubernetes Authors.
// SPDX-License-Identifier: Apache-2.0

//go:generate pluginator
package main

import (
	"fmt"
	"reflect"

	"sigs.k8s.io/kustomize/api/filters/replacement"
	"sigs.k8s.io/kustomize/api/resmap"
	"sigs.k8s.io/kustomize/api/types"
	"sigs.k8s.io/yaml"
)

// Replace values in targets with values from a source
type plugin struct {
	ReplacementList []types.ReplacementField `json:"replacements,omitempty" yaml:"replacements,omitempty"`
	replacements    []types.Replacement
}

var KustomizePlugin plugin //nolint:gochecknoglobals

func (p *plugin) Config(
	h *resmap.PluginHelpers, c []byte) (err error) {
	p.ReplacementList = []types.ReplacementField{}
	if err := yaml.Unmarshal(c, p); err != nil {
		return err
	}

	for _, r := range p.ReplacementList {
		if r.Path != "" && (r.Source != nil || len(r.Targets) != 0) {
			return fmt.Errorf("cannot specify both path and inline replacement")
		}
		if r.Path != "" {
			// load the replacement from the path
			content, err := h.Loader().Load(r.Path)
			if err != nil {
				return err
			}
			// find if the path contains a a list of replacements or a single replacement
			var replacement interface{}
			err = yaml.Unmarshal(content, &replacement)
			if err != nil {
				return err
			}
			items := reflect.ValueOf(replacement)
			switch items.Kind() {
			case reflect.Slice:
				repl := []types.Replacement{}
				if err := yaml.Unmarshal(content, &repl); err != nil {
					return err
				}
				p.replacements = append(p.replacements, repl...)
			case reflect.Map:
				repl := types.Replacement{}
				if err := yaml.Unmarshal(content, &repl); err != nil {
					return err
				}
				p.replacements = append(p.replacements, repl)
			default:
				return fmt.Errorf("unsupported replacement type encountered within replacement path: %v", items.Kind())
			}
		} else {
			// replacement information is already loaded
			p.replacements = append(p.replacements, r.Replacement)
		}
	}
	return nil
}

func (p *plugin) Transform(m resmap.ResMap) (err error) {
	return m.ApplyFilter(replacement.Filter{
		Replacements: p.replacements,
	})
}
