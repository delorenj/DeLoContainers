package dialog

import (
	"github.com/charmbracelet/bubbles/v2/key"
	"github.com/charmbracelet/bubbles/v2/textarea"
	tea "github.com/charmbracelet/bubbletea/v2"
	"github.com/charmbracelet/lipgloss/v2"
	"github.com/sst/opencode/internal/components/list"
	"github.com/sst/opencode/internal/layout"
	"github.com/sst/opencode/internal/status"
	"github.com/sst/opencode/internal/styles"
	"github.com/sst/opencode/internal/theme"
	"github.com/sst/opencode/internal/util"
)

type CompletionItem struct {
	title string
	Title string
	Value string
}

type CompletionItemI interface {
	list.ListItem
	GetValue() string
	DisplayValue() string
}

func (ci *CompletionItem) Render(selected bool, width int) string {
	t := theme.CurrentTheme()
	baseStyle := styles.BaseStyle()

	itemStyle := baseStyle.
		Background(t.BackgroundElement()).
		Width(width).
		Padding(0, 1)

	if selected {
		itemStyle = itemStyle.
			Foreground(t.Primary()).
			Bold(true)
	}

	title := itemStyle.Render(
		ci.DisplayValue(),
	)

	return title
}

func (ci *CompletionItem) DisplayValue() string {
	return ci.Title
}

func (ci *CompletionItem) GetValue() string {
	return ci.Value
}

func NewCompletionItem(completionItem CompletionItem) CompletionItemI {
	return &completionItem
}

type CompletionProvider interface {
	GetId() string
	GetEntry() CompletionItemI
	GetChildEntries(query string) ([]CompletionItemI, error)
}

type CompletionSelectedMsg struct {
	SearchString    string
	CompletionValue string
	IsCommand       bool
}

type CompletionDialogCompleteItemMsg struct {
	Value string
}

type CompletionDialogCloseMsg struct{}

type CompletionDialog interface {
	layout.ModelWithView
	SetWidth(width int)
	IsEmpty() bool
	SetProvider(provider CompletionProvider)
}

type completionDialogComponent struct {
	query                string
	completionProvider   CompletionProvider
	width                int
	height               int
	pseudoSearchTextArea textarea.Model
	list                 list.List[CompletionItemI]
}

type completionDialogKeyMap struct {
	Complete key.Binding
	Cancel   key.Binding
}

var completionDialogKeys = completionDialogKeyMap{
	Complete: key.NewBinding(
		key.WithKeys("tab", "enter"),
	),
	Cancel: key.NewBinding(
		key.WithKeys(" ", "esc", "backspace"),
	),
}

func (c *completionDialogComponent) Init() tea.Cmd {
	return nil
}

func (c *completionDialogComponent) complete(item CompletionItemI) tea.Cmd {
	value := c.pseudoSearchTextArea.Value()

	if value == "" {
		return nil
	}

	// Check if this is a command completion
	isCommand := c.completionProvider.GetId() == "commands"

	return tea.Batch(
		util.CmdHandler(CompletionSelectedMsg{
			SearchString:    value,
			CompletionValue: item.GetValue(),
			IsCommand:       isCommand,
		}),
		c.close(),
	)
}

func (c *completionDialogComponent) close() tea.Cmd {
	c.list.SetItems([]CompletionItemI{})
	c.pseudoSearchTextArea.Reset()
	c.pseudoSearchTextArea.Blur()

	return util.CmdHandler(CompletionDialogCloseMsg{})
}

func (c *completionDialogComponent) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if c.pseudoSearchTextArea.Focused() {
			if !key.Matches(msg, completionDialogKeys.Complete) {
				var cmd tea.Cmd
				c.pseudoSearchTextArea, cmd = c.pseudoSearchTextArea.Update(msg)
				cmds = append(cmds, cmd)

				var query string
				query = c.pseudoSearchTextArea.Value()
				if query != "" {
					query = query[1:]
				}

				if query != c.query {
					items, err := c.completionProvider.GetChildEntries(query)
					if err != nil {
						status.Error(err.Error())
					}

					c.list.SetItems(items)
					c.query = query
				}

				u, cmd := c.list.Update(msg)
				c.list = u.(list.List[CompletionItemI])

				cmds = append(cmds, cmd)
			}

			switch {
			case key.Matches(msg, completionDialogKeys.Complete):
				item, i := c.list.GetSelectedItem()
				if i == -1 {
					return c, nil
				}
				return c, c.complete(item)
			case key.Matches(msg, completionDialogKeys.Cancel):
				// Only close on backspace when there are no characters left
				if msg.String() != "backspace" || len(c.pseudoSearchTextArea.Value()) <= 0 {
					return c, c.close()
				}
			}

			return c, tea.Batch(cmds...)
		} else {
			items, err := c.completionProvider.GetChildEntries("")
			if err != nil {
				status.Error(err.Error())
			}

			c.list.SetItems(items)
			c.pseudoSearchTextArea.SetValue(msg.String())
			return c, c.pseudoSearchTextArea.Focus()
		}
	case tea.WindowSizeMsg:
		c.width = msg.Width
		c.height = msg.Height
	}

	return c, tea.Batch(cmds...)
}

func (c *completionDialogComponent) View() string {
	t := theme.CurrentTheme()
	baseStyle := styles.BaseStyle()

	maxWidth := 40
	completions := c.list.GetItems()

	for _, cmd := range completions {
		title := cmd.DisplayValue()
		if len(title) > maxWidth-4 {
			maxWidth = len(title) + 4
		}
	}

	c.list.SetMaxWidth(maxWidth)

	return baseStyle.Padding(0, 0).
		Background(t.BackgroundElement()).
		Border(lipgloss.ThickBorder()).
		BorderTop(false).
		BorderBottom(false).
		BorderRight(true).
		BorderLeft(true).
		BorderBackground(t.Background()).
		BorderForeground(t.BackgroundSubtle()).
		Width(c.width).
		Render(c.list.View())
}

func (c *completionDialogComponent) SetWidth(width int) {
	c.width = width
}

func (c *completionDialogComponent) IsEmpty() bool {
	return c.list.IsEmpty()
}

func (c *completionDialogComponent) SetProvider(provider CompletionProvider) {
	if c.completionProvider.GetId() != provider.GetId() {
		c.completionProvider = provider
		items, err := provider.GetChildEntries("")
		if err != nil {
			status.Error(err.Error())
		}
		c.list.SetItems(items)
	}
}

func NewCompletionDialogComponent(completionProvider CompletionProvider) CompletionDialog {
	ti := textarea.New()

	items, err := completionProvider.GetChildEntries("")
	if err != nil {
		status.Error(err.Error())
	}

	li := list.NewListComponent(
		items,
		7,
		"No matches",
		false,
	)

	return &completionDialogComponent{
		query:                "",
		completionProvider:   completionProvider,
		pseudoSearchTextArea: ti,
		list:                 li,
	}
}
