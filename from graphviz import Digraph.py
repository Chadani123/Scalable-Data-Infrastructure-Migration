from graphviz import Digraph

# Create a new directed graph
flowchart = Digraph(format='png', comment='Database Performance Troubleshooting')
flowchart.attr(rankdir='TB', size='10')

# Add nodes
flowchart.node('Start', 'Identify Database\nPerformance Issue', shape='ellipse', style='filled', color='lightblue')
flowchart.node('QuickFixes', 'Quick Fixes:\n- Optimize Queries\n- Add Missing Indexes\n- Clear Cache', shape='box')
flowchart.node('MediumTerm', 'Medium-Term Solutions:\n- Optimize Schema\n- Horizontal Partitioning\n- Review Workload Distribution', shape='box')
flowchart.node('LongTerm', 'Long-Term Architectural Changes:\n- Migrate to Scalable Infrastructure\n- Implement Load Balancers\n- Adopt NoSQL or Distributed Databases', shape='box')
flowchart.node('Monitoring', 'Monitoring:\n- Set Up Performance Monitoring Tools\n- Automate Alerts\n- Regular Maintenance', shape='box')
flowchart.node('Improved', 'Performance Improved?', shape='diamond', style='filled', color='lightgreen')
flowchart.node('Escalate', 'Escalate to Experts\n(DBA, Cloud Specialists)', shape='parallelogram')
flowchart.node('Continue', 'Continue Monitoring\nfor Issues', shape='ellipse', style='filled', color='lightblue')

# Add edges
flowchart.edge('Start', 'QuickFixes', label='Start Analysis')
flowchart.edge('QuickFixes', 'Improved', label='Evaluate Changes')
flowchart.edge('Improved', 'MediumTerm', label='No', color='red')
flowchart.edge('MediumTerm', 'LongTerm', label='If Needed')
flowchart.edge('LongTerm', 'Improved', label='Reevaluate', color='blue')
flowchart.edge('Improved', 'Monitoring', label='Yes', color='green')
flowchart.edge('Monitoring', 'Continue', label='Periodic Check')
flowchart.edge('Improved', 'Escalate', label='If Critical', color='red')

# Render the flowchart
flowchart_file_path = '/Users/chadaniacharya/Chand/TAMU/Fall 2024/ISTM 622/Furniture Project'
flowchart.render(flowchart_file_path, cleanup=True)
print(f"Flowchart successfully saved at {flowchart_file_path}.png")
