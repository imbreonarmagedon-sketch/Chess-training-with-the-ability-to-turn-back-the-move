package com.example.chess;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import android.graphics.Color;
import android.view.Gravity;

public class MainActivity extends Activity {
    private TextView statusText;
    private boolean isAnalysisOpen = false;
    private LinearLayout analysisPanel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Главный контейнер
        LinearLayout rootLayout = new LinearLayout(this);
        rootLayout.setOrientation(LinearLayout.VERTICAL);
        rootLayout.setBackgroundColor(Color.parseColor("#F5F5F5"));
        rootLayout.setPadding(16, 16, 16, 16);

        // Верхняя панель управления
        LinearLayout topBar = new LinearLayout(this);
        topBar.setOrientation(LinearLayout.HORIZONTAL);
        topBar.setGravity(Gravity.CENTER_VERTICAL);

        Button undoButton = new Button(this);
        undoButton.setText("Отменить ход");
        undoButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Toast.makeText(MainActivity.this, "Ход отменен!", Toast.LENGTH_SHORT).show();
            }
        });
        topBar.addView(undoButton);

        Button analysisButton = new Button(this);
        analysisButton.setText("AI Анализ");
        analysisButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                isAnalysisOpen = !isAnalysisOpen;
                analysisPanel.setVisibility(isAnalysisOpen ? View.VISIBLE : View.GONE);
            }
        });
        topBar.addView(analysisButton);

        rootLayout.addView(topBar);

        // Статус игры
        statusText = new TextView(this);
        statusText.setText("Шахматы с AI. Уровень: Средний. Ваш ход (Белые)");
        statusText.setTextSize(15);
        statusText.setPadding(0, 16, 0, 16);
        rootLayout.addView(statusText);

        // Область доски и панели
        LinearLayout contentLayout = new LinearLayout(this);
        contentLayout.setOrientation(LinearLayout.HORIZONTAL);

        // Игровая доска
        LinearLayout boardLayout = new LinearLayout(this);
        boardLayout.setOrientation(LinearLayout.VERTICAL);
        boardLayout.setBackgroundColor(Color.parseColor("#B58863"));
        boardLayout.setLayoutParams(new LinearLayout.LayoutParams(550, 550));
        
        TextView boardPlaceholder = new TextView(this);
        boardPlaceholder.setText("\n\n     [ Шахматная доска ]\n   Нажмите для хода");
        boardPlaceholder.setTextColor(Color.WHITE);
        boardPlaceholder.setTextSize(16);
        boardLayout.addView(boardPlaceholder);
        
        contentLayout.addView(boardLayout);

        // Боковая панель подсказок AI
        analysisPanel = new LinearLayout(this);
        analysisPanel.setOrientation(LinearLayout.VERTICAL);
        analysisPanel.setBackgroundColor(Color.parseColor("#EFEBE9"));
        analysisPanel.setPadding(8, 8, 8, 8);
        analysisPanel.setVisibility(View.GONE);

        TextView analysisTitle = new TextView(this);
        analysisTitle.setText("Анализ ИИ:\n1. e2-e4 (85%)\n2. d2-d4 (72%)\n3. c2-c4 (60%)");
        analysisTitle.setTextSize(13);
        analysisPanel.addView(analysisTitle);

        contentLayout.addView(analysisPanel);
        rootLayout.addView(contentLayout);

        setContentView(rootLayout);
    }
}
